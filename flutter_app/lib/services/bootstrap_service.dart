import 'dart:io';
import 'package:dio/dio.dart';
import '../constants.dart';
import '../models/setup_state.dart';
import 'native_bridge.dart';

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
  }) async {
    try {
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

      const resolvContent = 'nameserver 8.8.8.8\nnameserver 8.8.4.4\n';
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
            _updateSetupNotification('下载中：$mb / $totalMb MB', progress: notifProgress);
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

      _updateSetupNotification('正在修复 Rootfs 权限...', progress: 45);
      onProgress(const SetupState(
        step: SetupStep.installingPython,
        progress: 0.0,
        message: 'Fixing rootfs permissions...',
      ));
      await NativeBridge.runInProot(
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
        await NativeBridge.runInProot(
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
      await NativeBridge.runInProot('apt-get update -y');

      _updateSetupNotification('正在安装基础包...', progress: 52);
      onProgress(const SetupState(
        step: SetupStep.installingPython,
        progress: 0.15,
        message: '正在安装基础包...',
      ));
      await NativeBridge.runInProot(
        'ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime && '
        'echo "Etc/UTC" > /etc/timezone',
      );
      await NativeBridge.runInProot(
        'apt-get install -y --no-install-recommends '
        'ca-certificates git python3 python3-venv python3-pip curl wget',
      );

      // Clone with retry (GitHub CN unstable; --depth 1 cuts transfer a lot)
      const maxCloneAttempts = 3;
      for (int attempt = 1; attempt <= maxCloneAttempts; attempt++) {
        try {
          onProgress(SetupState(
            step: SetupStep.installingHermesAgent,
            progress: 0.0,
            message: '正在克隆 Hermes Agent 仓库...（第 $attempt/$maxCloneAttempts 次尝试）',
          ));
          _updateSetupNotification(
            '正在克隆 Hermes Agent 仓库（第 $attempt/$maxCloneAttempts 次）...',
            progress: 70,
          );
          await NativeBridge.runInProot(
            'cd /root && rm -rf hermes-agent && '
            'git clone --depth 1 https://github.com/nousresearch/hermes-agent.git hermes-agent',
            timeout: 600,
          );
          break;
        } catch (e) {
          if (attempt == maxCloneAttempts) rethrow;
          await Future.delayed(const Duration(seconds: 3));
        }
      }

      _updateSetupNotification('正在安装 Python 依赖...', progress: 85);
      onProgress(const SetupState(
        step: SetupStep.installingHermesAgent,
        progress: 0.5,
        message: '正在安装 Python 依赖...',
      ));
      // 1) create venv
      await NativeBridge.runInProot(
        'cd /root/hermes-agent && python3 -m venv venv',
        timeout: 120,
      );
      // 2) upgrade pip — ignore failure (proot may return nonzero even when ok)
      try {
        await NativeBridge.runInProot(
          'cd /root/hermes-agent && ./venv/bin/python -m pip install --upgrade pip',
          timeout: 300,
        );
      } catch (_) {}
      // 3) install dependencies — repo uses pyproject.toml (no requirements.txt)
      //    try requirements.txt first, fallback to pyproject.toml editable install
      try {
        await NativeBridge.runInProot(
          'cd /root/hermes-agent && ./venv/bin/python -m pip install -r requirements.txt',
          timeout: 1800,
        );
      } catch (_) {
        // requirements.txt missing (repo uses pyproject.toml); install from it
        await NativeBridge.runInProot(
          'cd /root/hermes-agent && ./venv/bin/python -m pip install -e ".[all]"',
          timeout: 1800,
        );
      }

      _updateSetupNotification('正在验证安装...', progress: 96);
      onProgress(const SetupState(
        step: SetupStep.installingHermesAgent,
        progress: 0.9,
        message: '正在验证 Hermes Agent 安装...',
      ));
      await NativeBridge.runInProot(
        'test -f /root/hermes-agent/gateway/run.py && echo hermes_ready',
      );
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
      onProgress(SetupState(
        step: SetupStep.error,
        error: '下载失败：${e.message}。请检查网络连接。',
      ));
    } catch (e) {
      _stopSetupService();
      onProgress(SetupState(
        step: SetupStep.error,
        error: '安装失败：$e',
      ));
    }
  }
}
