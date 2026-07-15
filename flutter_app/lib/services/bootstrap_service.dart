import 'dart:io';
import 'package:dio/dio.dart';
import '../constants.dart';
import '../models/setup_state.dart';
import 'native_bridge.dart';
import 'install_log.dart';

class BootstrapService {
  final Dio _dio = Dio();

  void _updateSetupNotification(String text, {int progress = -1}) {
    try {
      NativeBridge.updateSetupNotification(text, progress: progress);
    } catch (_) {}
  }

  void _stopSetupService() {
    try {
      NativeBridge.stopSetupService();
    } catch (_) {}
  }

  /// 检查 rootfs 是否已完整解压到 App 私有目录（无需进 proot）。
  Future<bool> _isRootfsExtracted(String filesDir) async {
    try {
      return Directory('$filesDir/rootfs/ubuntu/bin').existsSync() &&
          File('$filesDir/rootfs/ubuntu/bin/bash').existsSync();
    } catch (_) {
      return false;
    }
  }

  /// 在 proot 内检查某路径是否存在（用于断点续传判断，失败返回 false）。
  Future<bool> _prootPathExists(String path) async {
    try {
      final out = await NativeBridge.runInProot(
        'test -e "$path" && echo __yes__',
        timeout: 30,
      );
      return out.contains('__yes__');
    } catch (_) {
      return false;
    }
  }

  /// 在 proot 内验证 hermes CLI 是否真正可用（依赖是否真的装好）。
  /// 不再只看 run.py / venv/bin/python 文件是否存在——那些在 pip 失败时也会存在。
  Future<bool> _verifyHermesCli() async {
    try {
      final out = await NativeBridge.runInProot(
        'cd /root/hermes-agent && (./venv/bin/hermes --version 2>&1 || '
        './venv/bin/python -c "import hermes; print(hermes.__version__)" 2>&1) '
        '|| echo __HERMES_BROKEN__',
        timeout: 60,
      );
      final trimmed = out.trim();
      return trimmed.isNotEmpty && !trimmed.contains('__HERMES_BROKEN__');
    } catch (_) {
      return false;
    }
  }

  Future<SetupState> checkStatus() async {
    try {
      final complete = await NativeBridge.isBootstrapComplete();
      if (complete) {
        return const SetupState(
          step: SetupStep.complete,
          progress: 1.0,
          message: '安装完成',
        );
      }
      return const SetupState(
        step: SetupStep.checkingStatus,
        progress: 0.0,
        message: '需要安装',
      );
    } catch (e) {
      return SetupState(
        step: SetupStep.error,
        error: '检查失败：$e',
      );
    }
  }

  Future<void> runFullSetup({
    required void Function(SetupState) onProgress,
    void Function(String)? onLog,
  }) async {
    // 日志 helper：同时写文件 + 推给 UI 实时显示
    void log(String line) {
      InstallLog.append(line);
      onLog?.call(line);
    }

    // 在 proot 里执行命令并记录：命令本身 + 输出 + 报错
    Future<String> prootRun(String command, {int timeout = 900}) async {
      log('\$ $command');
      try {
        final out = await NativeBridge.runInProot(command, timeout: timeout);
        if (out.trim().isNotEmpty) log(out.trim());
        return out;
      } catch (e) {
        log('✗ 命令失败: $e');
        rethrow;
      }
    }

    const maxCloneAttempts = 3;

    try {
      await InstallLog.init();
      try {
        await NativeBridge.startSetupService();
      } catch (_) {}

      onProgress(const SetupState(
        step: SetupStep.checkingStatus,
        progress: 0.0,
        message: '正在创建目录...',
      ));
      _updateSetupNotification('正在创建目录...', progress: 2);
      try { await NativeBridge.setupDirs(); } catch (_) {}
      try { await NativeBridge.writeResolv(); } catch (_) {}

      final arch = await NativeBridge.getArch();
      final rootfsUrl = AppConstants.getRootfsUrl(arch);
      final filesDir = await NativeBridge.getFilesDir();

      // DNS 改国内公共 DNS（解决国内手机直连 GitHub 解析失败 / 超时）
      const resolvContent = AppConstants.prootResolv;
      try {
        final configDir = '$filesDir/config';
        final resolvFile = File('$configDir/resolv.conf');
        if (!resolvFile.existsSync()) {
          Directory(configDir).createSync(recursive: true);
          resolvFile.writeAsStringSync(resolvContent);
        }
        final rootfsResolv = File('$filesDir/rootfs/ubuntu/etc/resolv.conf');
        if (!rootfsResolv.existsSync()) {
          rootfsResolv.parent.createSync(recursive: true);
          rootfsResolv.writeAsStringSync(resolvContent);
        }
      } catch (_) {}
      final tarPath = '$filesDir/tmp/ubuntu-rootfs.tar.gz';

      // ===== 断点续传：rootfs 已解压则跳过下载 + 解压 =====
      final rootfsReady = await _isRootfsExtracted(filesDir);
      if (!rootfsReady) {
        _updateSetupNotification('正在下载 Ubuntu Rootfs...', progress: 5);
        onProgress(const SetupState(
          step: SetupStep.downloadingRootfs,
          progress: 0.0,
          message: '正在下载 Ubuntu Rootfs...',
        ));
        await _dio.download(
          rootfsUrl,
          tarPath,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              final progress = received / total;
              final mb = (received / 1024 / 1024).toStringAsFixed(1);
              final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
              final notifProgress = 5 + (progress * 25).round();
              _updateSetupNotification('下载中：$mb / $totalMb MB',
                  progress: notifProgress);
              onProgress(SetupState(
                step: SetupStep.downloadingRootfs,
                progress: progress,
                message: '下载中：$mb MB / $totalMb MB',
              ));
            }
          },
        );

        _updateSetupNotification('正在解压 Rootfs...', progress: 30);
        onProgress(const SetupState(
          step: SetupStep.extractingRootfs,
          progress: 0.0,
          message: '正在解压 Rootfs（需要较长时间）...',
        ));
        await NativeBridge.extractRootfs(tarPath);
        onProgress(const SetupState(
          step: SetupStep.extractingRootfs,
          progress: 1.0,
          message: 'Rootfs 解压完成',
        ));
      } else {
        log('ℹ Rootfs 已存在，跳过下载与解压');
        onProgress(const SetupState(
          step: SetupStep.extractingRootfs,
          progress: 1.0,
          message: 'Rootfs 已存在，跳过下载与解压',
        ));
        _updateSetupNotification('Rootfs 已存在，跳过', progress: 30);
      }

      // ===== 断点续传：python3 已装则跳过权限修复 + apt =====
      final pythonReady = await _prootPathExists('/usr/bin/python3');
      if (!pythonReady) {
        _updateSetupNotification('正在修复 Rootfs 权限...', progress: 45);
        onProgress(const SetupState(
          step: SetupStep.installingPython,
          progress: 0.0,
          message: 'Fixing rootfs permissions...',
        ));
        await prootRun(
          'chmod -R 755 /usr/bin /usr/sbin /bin /sbin '
          '/usr/local/bin /usr/local/sbin 2>/dev/null; '
          'chmod -R +x /usr/lib/apt/ /usr/lib/dpkg/ /usr/libexec/ '
          '/var/lib/dpkg/info/ /usr/share/debconf/ 2>/dev/null; '
          'chmod 755 /lib/*/ld-linux-*.so* /usr/lib/*/ld-linux-*.so* 2>/dev/null; '
          'mkdir -p /var/lib/dpkg/updates /var/lib/dpkg/triggers; '
          'echo permissions_fixed',
        );

        // Auto-recover interrupted dpkg (common after crashed installs)
        _updateSetupNotification('正在修复包数据库...', progress: 47);
        onProgress(const SetupState(
          step: SetupStep.installingPython,
          progress: 0.05,
          message: '正在修复包数据库...',
        ));
        try {
          await prootRun(
            'dpkg --configure -a 2>/dev/null || true',
            timeout: 300,
          );
        } catch (_) {}

        _updateSetupNotification('正在更新软件源列表...', progress: 48);
        onProgress(const SetupState(
          step: SetupStep.installingPython,
          progress: 0.1,
          message: '正在更新软件源列表...',
        ));
        // 将 apt 系统源替换为阿里云国内源（Ubuntu 官方源国内极慢/超时，
        // 是手机第四步卡顿的常见原因）。arm64 用 ubuntu-ports 仓库。
        await prootRun(
          'sed -i "s|archive.ubuntu.com|${AppConstants.aptMirrorHost}|g; '
          's|security.ubuntu.com|${AppConstants.aptMirrorHost}|g" '
          '/etc/apt/sources.list '
          '\$(ls /etc/apt/sources.list.d/*.list 2>/dev/null) 2>/dev/null; '
          'echo apt_mirror_switched',
          timeout: 120,
        );
        await prootRun('apt-get update -y');

        _updateSetupNotification('正在安装基础包...', progress: 52);
        onProgress(const SetupState(
          step: SetupStep.installingPython,
          progress: 0.15,
          message: '正在安装基础包...',
        ));
        await prootRun(
          'ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime && '
          'echo "Etc/UTC" > /etc/timezone',
        );
        await prootRun(
          'apt-get install -y --no-install-recommends '
          'ca-certificates git python3 python3-venv python3-pip curl wget',
        );
      } else {
        log('ℹ Python 基础环境已存在，跳过权限修复与 apt 安装');
        onProgress(const SetupState(
          step: SetupStep.installingPython,
          progress: 0.2,
          message: '基础环境已存在，跳过',
        ));
        _updateSetupNotification('基础环境已存在，跳过', progress: 52);
      }

      // ===== 断点续传：hermes-agent 已克隆则跳过 =====
      final hermesReady =
          await _prootPathExists('/root/hermes-agent/gateway/run.py');
      if (!hermesReady) {
        // 多镜像源依次尝试，前一个失败自动切换下一个（国内镜像优先）
        bool cloned = false;
        final mirrors = AppConstants.hermesAgentMirrorUrls;
        for (int mi = 0; mi < mirrors.length; mi++) {
          for (int attempt = 1; attempt <= maxCloneAttempts; attempt++) {
            try {
              onProgress(SetupState(
                step: SetupStep.installingHermesAgent,
                progress: 0.0,
                message:
                    '正在克隆 Hermes Agent（镜像 ${mi + 1}/${mirrors.length}，第 $attempt 次）...',
              ));
              _updateSetupNotification(
                '正在克隆 Hermes Agent（镜像 ${mi + 1}/${mirrors.length}）...',
                progress: 70,
              );
              await prootRun(
                'cd /root && rm -rf hermes-agent && '
                'git clone --depth 1 ${mirrors[mi]} hermes-agent',
                timeout: 600,
              );
              cloned = true;
              break;
            } catch (e) {
              if (attempt == maxCloneAttempts) {
                log('✗ 镜像 ${mirrors[mi]} 失败，尝试下一个');
              } else {
                await Future.delayed(const Duration(seconds: 3));
              }
            }
          }
          if (cloned) break;
        }
        if (!cloned) {
          throw Exception('所有镜像源克隆均失败，请检查网络或稍后重试');
        }
      } else {
        log('ℹ hermes-agent 已存在，跳过克隆');
        onProgress(const SetupState(
          step: SetupStep.installingHermesAgent,
          progress: 0.3,
          message: 'Hermes Agent 已存在，跳过克隆',
        ));
        _updateSetupNotification('Hermes Agent 已存在，跳过', progress: 75);
      }

      // ===== 断点续传：venv 已建则跳过 venv + pip =====
      // 只有 venv/bin/hermes（pip 真正装好的证据）存在才算就绪。
      // 旧逻辑只看 venv/bin/python，导致「venv 建了但依赖没装」也被判为就绪，
      // 重新初始化时被跳过，永远修不好。
      final venvReady =
          await _prootPathExists('/root/hermes-agent/venv/bin/hermes');
      if (!venvReady) {
        _updateSetupNotification('正在安装 Python 依赖...', progress: 85);
        onProgress(const SetupState(
          step: SetupStep.installingHermesAgent,
          progress: 0.5,
          message: '正在安装 Python 依赖...',
        ));
        // 1) create venv
        await prootRun(
          'cd /root/hermes-agent && python3 -m venv venv',
          timeout: 120,
        );
        // 2) upgrade pip — ignore failure (proot may return nonzero even when ok)
        try {
          await prootRun(
            'cd /root/hermes-agent && ./venv/bin/python -m pip install --upgrade pip',
            timeout: 300,
          );
        } catch (_) {}
        // 3) install dependencies.
        //    仓库用 pyproject.toml（没有 requirements.txt），主装方式必须是
        //    `pip install -e ".[all]"`。之前先把 requirements.txt 当首选会导致
        //    反复 1800s 超时失败（文件根本不存在），只靠最后的 `.[all]` 兜底，
        //    一旦 `.[all]` 也失败就被静默吞掉、照样报「完成」。
        //    现在改为 `.[all]` 首选 + 双镜像，全部失败才抛错。
        const pipPrimary = AppConstants.pipIndexUrl;
        const pipFallback = AppConstants.pipFallbackUrl;
        var depsInstalled = false;
        for (final mirror in [pipPrimary, pipFallback]) {
          try {
            await prootRun(
              'cd /root/hermes-agent && ./venv/bin/python -m pip install -e ".[all]" -i $mirror',
              timeout: 1800,
            );
            depsInstalled = true;
            break;
          } catch (e) {
            log('⚠ pip 安装失败（镜像 $mirror），尝试下一个');
          }
        }
        if (!depsInstalled) {
          // 兜底：个别分支可能带 requirements.txt
          try {
            await prootRun(
              'cd /root/hermes-agent && ./venv/bin/python -m pip install -r requirements.txt -i $pipPrimary',
              timeout: 1800,
            );
            depsInstalled = true;
          } catch (_) {}
        }
        if (!depsInstalled) {
          throw Exception(
              'Hermes Python 依赖安装失败（所有 pip 镜像均失败）。请检查网络后重试，或在终端手动 pip 安装。');
        }
      } else {
        log('ℹ venv 已存在，跳过依赖安装');
        onProgress(const SetupState(
          step: SetupStep.installingHermesAgent,
          progress: 0.6,
          message: '依赖已安装，跳过',
        ));
        _updateSetupNotification('依赖已安装，跳过', progress: 90);
      }

      _updateSetupNotification('正在验证安装...', progress: 96);
      onProgress(const SetupState(
        step: SetupStep.installingHermesAgent,
        progress: 0.9,
        message: '正在验证 Hermes Agent 安装...',
      ));
      // 真实验证：hermes CLI 必须能跑起来（不再只看 run.py 文件在不在）
      final hermesOk = await _verifyHermesCli();
      if (!hermesOk) {
        throw Exception(
            'Hermes 依赖安装后仍不可用（venv/bin/hermes 无法运行）。请检查 pip 镜像源后重试。');
      }
      log('✔ Hermes CLI 可用，依赖安装完成');
      onProgress(const SetupState(
        step: SetupStep.installingHermesAgent,
        progress: 1.0,
        message: 'Hermes Agent 安装完成',
      ));

      _updateSetupNotification('安装完成！', progress: 100);
      onProgress(const SetupState(
        step: SetupStep.configuringEnvironment,
        progress: 1.0,
        message: '环境配置完成',
      ));

      _stopSetupService();
      onProgress(const SetupState(
        step: SetupStep.complete,
        progress: 1.0,
        message: '安装完成！可以开始使用 Agent 了。',
      ));
    } on DioException catch (e) {
      _stopSetupService();
      log('✗ 下载失败: ${e.message}');
      onProgress(SetupState(
        step: SetupStep.error,
        error: '下载失败：${e.message}。请检查网络连接。',
      ));
    } catch (e) {
      _stopSetupService();
      log('✗ 安装失败: $e');
      onProgress(SetupState(
        step: SetupStep.error,
        error: '安装失败：$e',
      ));
    }
  }
}
