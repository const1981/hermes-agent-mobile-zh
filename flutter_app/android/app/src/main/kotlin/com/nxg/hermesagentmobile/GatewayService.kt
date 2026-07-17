package com.nxg.hermesagentmobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import io.flutter.plugin.common.EventChannel
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.net.InetSocketAddress
import java.net.Socket

class GatewayService : Service() {
    companion object {
        const val CHANNEL_ID = "hermes_gateway"
        const val NOTIFICATION_ID = 1
        var isRunning = false
            private set
        var logSink: EventChannel.EventSink? = null
        private var instance: GatewayService? = null
        private val mainHandler = Handler(Looper.getMainLooper())

        // 【v0.3.38】网关启动脚本：清理残留进程 + 切目录 + exec 网关。
        // 全程只用 Python 标准库（os/glob/sys），不调用 shell、不建 pipe、
        // 不碰 /dev/null —— 规避部分 Android/proot 环境的 "Function not
        // implemented" 问题。由 venv python 直接 exec 本脚本（不经 bash）。
        private const val LAUNCH_SCRIPT = """import os, glob, sys

me = os.getpid()
ppid = os.getppid()

def kill(pid):
    try:
        os.kill(int(pid), 9)
    except Exception:
        pass

# 1) Kill by Hermes PID file (most reliable)
try:
    with open('/root/.hermes/gateway.pid') as f:
        pid = int(f.read().strip())
        if pid != me and pid != ppid:
            kill(pid)
except Exception:
    pass

# 2) Fallback: scan /proc for any stale gateway processes.
#    Use file I/O only — no subprocess/pipes/dev-null.
for p in glob.glob('/proc/[0-9]*/cmdline'):
    try:
        with open(p, 'rb') as f:
            cmd = f.read().replace(b'\\x00', b' ').decode('utf-8', 'replace')
        if 'gateway/run.py' in cmd or 'hermes-gateway' in cmd:
            pid = int(p.split('/')[2])
            if pid != me and pid != ppid:
                kill(pid)
    except Exception:
        pass

# 3) Build a gateway config that ENABLES the local api_server platform.
#    The user's config.yaml has no top-level `platforms:` section, so the
#    gateway starts but binds NO HTTP port (logs "No messaging platforms
#    enabled") and the App cannot connect (Connection refused on 127.0.0.1:18789).
#    We merge an api_server block on top of the existing config.yaml (preserving
#    the model/provider settings) and launch with --config so the port is bound.
import json
try:
    import yaml
    _have_yaml = True
except Exception:
    _have_yaml = False

_cfg = {}
if _have_yaml:
    try:
        with open('/root/.hermes/config.yaml', 'r', encoding='utf-8') as f:
            _cfg = yaml.safe_load(f) or {}
    except Exception:
        _cfg = {}
if not isinstance(_cfg, dict):
    _cfg = {}

_platforms = _cfg.get('platforms')
if not isinstance(_platforms, dict):
    _platforms = {}
_platforms['api_server'] = {
    'enabled': True,
    'host': '127.0.0.1',
    'port': 18789,
}
_cfg['platforms'] = _platforms

with open('/root/.hermes/mobile_gateway.yaml', 'w', encoding='utf-8') as f:
    if _have_yaml:
        yaml.safe_dump(_cfg, f, default_flow_style=False, allow_unicode=True)
    else:
        json.dump(_cfg, f)

# 4) Change to hermes-agent dir and exec the gateway with our merged config.
#    os.execv replaces the current process (no extra shell layer).
os.chdir('/root/hermes-agent')
venv_python = '/root/hermes-agent/venv/bin/python'
cfg_path = '/root/.hermes/mobile_gateway.yaml'
os.execv(venv_python, [venv_python, 'gateway/run.py', '--config', cfg_path])
"""

        /** Check if the gateway process is actually alive (not just the flag).
         *  Safe to call from the main thread — no blocking I/O. */
        fun isProcessAlive(): Boolean {
            val inst = instance ?: return false
            if (!isRunning) return false
            val proc = inst.gatewayProcess
            // If we have a process reference, check if it's actually alive
            if (proc != null) return proc.isAlive
            // No process ref yet — still in setup phase.
            // If the gateway thread is alive, setup is ongoing — report true.
            // This covers slow devices where dir setup takes a long time.
            val thread = inst.gatewayThread
            if (thread != null && thread.isAlive) return true
            // Fallback: within startup window (120s)
            val elapsed = System.currentTimeMillis() - inst.startTime
            return elapsed < 120_000
        }

        fun start(context: Context) {
            val intent = Intent(context, GatewayService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, GatewayService::class.java)
            context.stopService(intent)
        }
    }

    private var gatewayProcess: Process? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var restartCount = 0
    private val maxRestarts = 5
    private var startTime: Long = 0
    private var processStartTime: Long = 0
    private var uptimeThread: Thread? = null
    private var watchdogThread: Thread? = null
    private var gatewayThread: Thread? = null
    private val lock = Object()
    @Volatile private var stopping = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification("Starting..."))
        if (isRunning) {
            updateNotificationRunning()
            return START_STICKY
        }
        stopping = false
        acquireWakeLock()
        startGateway()
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        instance = null
        uptimeThread?.interrupt()
        uptimeThread = null
        watchdogThread?.interrupt()
        watchdogThread = null
        stopGateway()
        releaseWakeLock()
        super.onDestroy()
    }

    /** Check if gateway port is already in use (another instance running). */
    private fun isPortInUse(port: Int = 18789): Boolean {
        return try {
            Socket().use { socket ->
                socket.connect(InetSocketAddress("127.0.0.1", port), 1000)
                true
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun startGateway() {
        synchronized(lock) {
            if (stopping) return
            if (gatewayProcess?.isAlive == true) return

            isRunning = true
            instance = this
            startTime = System.currentTimeMillis()
        }

        gatewayThread = Thread {
            try {
                // Check if an existing gateway is already listening on the port.
                // Moved inside thread to avoid blocking the main thread (#60).
                if (isPortInUse()) {
                    // Wait briefly for TIME_WAIT socket to clear after a manual stop
                    var waited = 0
                    while (waited < 3000 && isPortInUse()) {
                        Thread.sleep(300)
                        waited += 300
                    }
                    if (isPortInUse()) {
                        emitLog("[INFO] Gateway already running on port 18789, adopting existing instance")
                        updateNotificationRunning()
                        startUptimeTicker()
                        startWatchdog()
                        return@Thread
                    }
                }

                emitLog("[INFO] Setting up environment...")
                val filesDir = applicationContext.filesDir.absolutePath
                val nativeLibDir = applicationContext.applicationInfo.nativeLibraryDir
                val pm = ProcessManager(filesDir, nativeLibDir)

                // Recreate all directories (config, tmp, home, lib, proc/sys fakes)
                // in case Android cleared them after an app update (#40).
                // This must run before proot — it needs bind-mount targets.
                val bootstrapManager = BootstrapManager(applicationContext, filesDir, nativeLibDir)
                try {
                    bootstrapManager.setupDirectories()
                    emitLog("[INFO] Directories ready")
                } catch (e: Exception) {
                    emitLog("[WARN] setupDirectories failed: ${e.message}")
                }
                // Ensure `hermes` CLI is on PATH (for terminal users and
                // `hermes skills install`); covers users with an existing
                // rootfs that predates the symlink.
                try {
                    bootstrapManager.ensureHermesCli()
                } catch (_: Exception) {}
                try {
                    bootstrapManager.writeResolvConf()
                } catch (e: Exception) {
                    emitLog("[WARN] writeResolvConf failed: ${e.message}")
                }

                // Last-resort: verify resolv.conf exists, create inline if not
                val resolvContent = "nameserver 119.29.11.29\nnameserver 223.5.5.5\n"
                try {
                    val resolvFile = File(filesDir, "config/resolv.conf")
                    if (!resolvFile.exists() || resolvFile.length() == 0L) {
                        resolvFile.parentFile?.mkdirs()
                        resolvFile.writeText(resolvContent)
                        emitLog("[INFO] resolv.conf created (inline fallback)")
                    }
                } catch (e: Exception) {
                    emitLog("[WARN] inline resolv.conf fallback failed: ${e.message}")
                }
                // Also write into rootfs /etc/ so DNS works even if bind-mount fails
                try {
                    val rootfsResolv = File(filesDir, "rootfs/debian/etc/resolv.conf")
                    if (!rootfsResolv.exists() || rootfsResolv.length() == 0L) {
                        rootfsResolv.parentFile?.mkdirs()
                        rootfsResolv.writeText(resolvContent)
                    }
                } catch (_: Exception) {}

                // Write the Python launch script into the rootfs. We use it instead of
                // bash command substitution / pipes because some Android/proot
                // environments do not support /dev/null or pipes ("Function not
                // implemented"), and /bin/bash exec of the python binary also fails
                // with ENOSYS. Python file I/O, os.kill, os.chdir and os.execv all
                // work without a shell layer.
                ensureLaunchScript(filesDir)

                // Abort if stop was requested during setup
                if (stopping) return@Thread

                // Final check right before launch — another instance may have
                // started between the first check and now
                if (isPortInUse()) {
                    // Wait briefly for TIME_WAIT socket to clear after a manual stop
                    var waited = 0
                    while (waited < 3000 && isPortInUse()) {
                        Thread.sleep(300)
                        waited += 300
                    }
                    if (isPortInUse()) {
                        emitLog("Gateway already running on port 18789, skipping launch")
                        updateNotificationRunning()
                        startUptimeTicker()
                        startWatchdog()
                        return@Thread
                    }
                }

                // ===== 起飞前自检：venv/bin/hermes 是否真正可用 =====
                // 引导只检查 run.py 在不在，pip 失败会导致「完成」但依赖缺失，
                // 网关一启动就 ImportError 秒退、proot 整体退出 → 表现为「启动即关闭」。
                // 这里提前发现，给出清晰中文报错，而不是崩→重启→崩死循环。
                // 【v0.3.34 修复】原实现会在启动前先 runInProotSync 跑一次
                // `hermes --version` 做"软自检"——但每次都要冷启动一个完整 proot
                // 进程，中低端机/异常 rootfs 下会卡 15 分钟（默认 900s 超时），
                // 表现为「网关一直 starting 起不来」。改为只检查文件存在，
                // 真正的运行校验交给下方 launchCmd 本身（失败看 stderr 日志即可）。
                val hermesBin = File("$filesDir/rootfs/debian/root/hermes-agent/venv/bin/hermes")
                if (!hermesBin.exists()) {
                    emitLog("[ERROR] Hermes 依赖未安装完整（venv/bin/hermes 不存在）。请前往「设置 → 重新初始化」修复后，再启动网关。")
                    updateNotification("Hermes 依赖缺失，请重新初始化")
                    isRunning = false
                    return@Thread
                }
                emitLog("[INFO] Hermes venv 文件就绪，跳过 proot 软自检（避免冷启动卡死）")

                    emitLog("[INFO] Spawning proot process...")
                    synchronized(lock) {
                        if (stopping) return@Thread
                        processStartTime = System.currentTimeMillis()
                        // 启动前先清理可能残留的 gateway 进程（杀后台/崩溃后旧实例没退，
                        // 会导致 Hermes 报 "Gateway already running" 并启动失败）。
                        emitLog("[INFO] Cleaning up stale gateway process...")
                        // 注意：v0.3.29 用 pkill -f gateway/run.py 会把自己的 shell 也匹配上并
                        // SIGKILL（exit 137 自杀）。v0.3.31 改用 bash 命令替换，但部分 Android/proot
                        // 环境里 /dev/null 和 pipe 不支持，命令替换直接失败。v0.3.32 改 Python 清理
                        // 脚本，但仍经 /bin/bash -c 启动，本机 proot 下 bash exec python 报
                        // "Function not implemented"（ENOSYS），网关 0 秒崩（exit 137）。
                        // v0.3.38：彻底去掉 bash 中间层——由 venv python 直接 exec launch 脚本，
                        // 脚本内 os.chdir + os.execv 完成切目录与启动，全程无 shell。
                        val launchScript = "/root/.hermes/launch_gateway.py"
                        gatewayProcess = pm.startProotProcess(launchScript)
                    }
                updateNotificationRunning()
                emitLog("[INFO] Gateway process spawned")
                startUptimeTicker()
                startWatchdog()

                // Read stdout
                val proc = gatewayProcess!!
                val stdoutReader = BufferedReader(InputStreamReader(proc.inputStream))
                Thread {
                    try {
                        var line: String?
                        while (stdoutReader.readLine().also { line = it } != null) {
                            val l = line ?: continue
                            emitLog(l)
                        }
                    } catch (_: Exception) {}
                }.start()

                // Read stderr — log all lines on first attempt for debugging visibility
                val stderrReader = BufferedReader(InputStreamReader(proc.errorStream))
                val currentRestartCount = restartCount
                Thread {
                    try {
                        var line: String?
                        while (stderrReader.readLine().also { line = it } != null) {
                            val l = line ?: continue
                            if (currentRestartCount == 0 ||
                                (!l.contains("proot warning") && !l.contains("can't sanitize"))) {
                                emitLog("[ERR] $l")
                            }
                        }
                    } catch (_: Exception) {}
                }.start()

                val exitCode = proc.waitFor()
                val uptimeMs = System.currentTimeMillis() - processStartTime
                val uptimeSec = uptimeMs / 1000
                emitLog("[INFO] Gateway exited with code $exitCode (uptime: ${uptimeSec}s)")

                // 用户明确要求：网关只由仪表盘手动启停，崩溃后不自动重启。
                // 进程退出（无论是否崩溃）一律标记为停止，等待用户再次点「启动网关」。
                if (stopping) return@Thread

                restartCount = 0
                isRunning = false
                emitLog("[INFO] Gateway stopped (no auto-restart by design). Tap 启动网关 to start again.")
                updateNotification("网关已停止（不自动重启）")
            } catch (e: Exception) {
                if (!stopping) {
                    emitLog("[ERROR] Gateway error: ${e.message}")
                    isRunning = false
                    updateNotification("Gateway error")
                }
            }
        }.also { it.start() }
    }

    private fun ensureLaunchScript(filesDir: String) {
        try {
            val script = File("$filesDir/rootfs/debian/root/.hermes/launch_gateway.py")
            script.parentFile?.mkdirs()
            script.writeText(LAUNCH_SCRIPT)
        } catch (_: Exception) {}
    }

    private fun stopGateway() {
        val procToStop: Process?
        synchronized(lock) {
            stopping = true
            restartCount = maxRestarts
            uptimeThread?.interrupt()
            uptimeThread = null
            watchdogThread?.interrupt()
            watchdogThread = null
            gatewayThread?.interrupt()
            gatewayThread = null
            procToStop = gatewayProcess
            gatewayProcess = null
        }
        emitLog("Gateway stopped by user")
        val filesDir = applicationContext.filesDir.absolutePath
        Thread({
            // Best-effort: kill the inner Python gateway directly via its PID
            // file. Under proot --kill-on-exit, terminating the proot wrapper
            // below automatically reaps the inner Python process, so this is
            // only a belt-and-suspenders measure. We never kill the host app
            // here — that previously caused an instant crash on "stop gateway".
            val pythonPid = try {
                val pidFile = File("$filesDir/rootfs/debian/root/.hermes/gateway.pid")
                if (pidFile.exists()) pidFile.readText().trim() else null
            } catch (_: Exception) {
                null
            }

            if (!pythonPid.isNullOrEmpty()) {
                try {
                    Runtime.getRuntime().exec(arrayOf("kill", "-9", pythonPid))
                } catch (_: Exception) {}
            }

            // Terminate the proot wrapper. With --kill-on-exit this also reaps
            // the inner gateway. Never kill the host app process.
            procToStop?.let { proc ->
                try {
                    proc.destroy()
                    if (!proc.waitFor(3, java.util.concurrent.TimeUnit.SECONDS)) {
                        proc.destroyForcibly()
                    }
                } catch (_: Exception) {
                    try { proc.destroyForcibly() } catch (_: Exception) {}
                }
            }
            emitLog("[INFO] Gateway process tree terminated")
        }, "gateway-stop").apply { isDaemon = true }.start()
    }

    /** Watchdog: periodically checks if the proot process is alive.
     *  If the process dies and the waitFor() thread hasn't noticed yet,
     *  this ensures isRunning is updated promptly. */
    private fun startWatchdog() {
        watchdogThread?.interrupt()
        watchdogThread = Thread {
            try {
                // Wait 45s before first check — give the process time to start
                Thread.sleep(45_000)
                while (!Thread.interrupted() && isRunning && !stopping) {
                    val proc = gatewayProcess
                    if (proc != null && !proc.isAlive) {
                        // Process died — the waitFor() thread should handle restart,
                        // but update the flag in case it's stuck
                        emitLog("[WARN] Watchdog: gateway process not alive")
                        break
                    }
                    // Also check if port is still responding after initial startup
                    if (proc != null && !isPortInUse()) {
                        emitLog("[WARN] Watchdog: port 18789 not responding")
                    }
                    Thread.sleep(15_000) // Check every 15s
                }
            } catch (_: InterruptedException) {}
        }.apply { isDaemon = true; start() }
    }

    private fun startUptimeTicker() {
        uptimeThread?.interrupt()
        uptimeThread = Thread {
            try {
                while (!Thread.interrupted() && isRunning) {
                    Thread.sleep(60_000) // Update every minute
                    if (isRunning) {
                        updateNotificationRunning()
                    }
                }
            } catch (_: InterruptedException) {}
        }.apply { isDaemon = true; start() }
    }

    private fun formatUptime(): String {
        val elapsed = System.currentTimeMillis() - startTime
        val seconds = elapsed / 1000
        val minutes = seconds / 60
        val hours = minutes / 60
        return when {
            hours > 0 -> "${hours}h ${minutes % 60}m"
            minutes > 0 -> "${minutes}m"
            else -> "${seconds}s"
        }
    }

    private fun updateNotificationRunning() {
        updateNotification("Running on port 18789 \u2022 ${formatUptime()}")
    }

    /** Emit a log message to the Flutter EventChannel.
     *  MUST post to main thread — EventSink.success() is not thread-safe. */
    private fun emitLog(message: String) {
        try {
            val ts = java.time.Instant.now().toString()
            val formatted = "$ts $message"
            mainHandler.post {
                try {
                    logSink?.success(formatted)
                } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
    }

    private fun acquireWakeLock() {
        releaseWakeLock()
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "Hermes Agent::GatewayWakeLock"
        )
        wakeLock?.acquire(24 * 60 * 60 * 1000L) // 24 hours max
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Hermes Agent Gateway",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the Hermes Agent gateway running in the background"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder.setContentTitle("Hermes Agent Gateway")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(pendingIntent)
            .setOngoing(true)

        // Show elapsed time chronometer when running
        if (isRunning && startTime > 0) {
            builder.setWhen(startTime)
            builder.setShowWhen(true)
            builder.setUsesChronometer(true)
        }

        return builder.build()
    }

    private fun updateNotification(text: String) {
        try {
            val manager = getSystemService(NotificationManager::class.java)
            manager.notify(NOTIFICATION_ID, buildNotification(text))
        } catch (_: Exception) {}
    }
}
