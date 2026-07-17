import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import '../l10n/app_strings.dart';
import '../services/native_bridge.dart';
import '../services/preferences_service.dart';
import '../services/snapshot_service.dart';
import 'setup_wizard_screen.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  String _status = 'Loading...';
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  // ── i18n helper ───────────────────────
  AppStrings get s => AppStrings.of(context);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _status = s.loading;
    _checkAndRoute();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _checkAndRoute() async {
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      setState(() => _status = s.checkingSetup);

      try { await NativeBridge.setupDirs(); } catch (_) {}
      try { await NativeBridge.writeResolv(); } catch (_) {}
      try {
        final filesDir = await NativeBridge.getFilesDir();
        const resolvContent = AppConstants.prootResolv;
        final resolvFile = File('$filesDir/config/resolv.conf');
        if (!resolvFile.existsSync()) {
          Directory('$filesDir/config').createSync(recursive: true);
          resolvFile.writeAsStringSync(resolvContent);
        }
        final rootfsResolv = File('$filesDir/rootfs/debian/etc/resolv.conf');
        if (!rootfsResolv.existsSync()) {
          rootfsResolv.parent.createSync(recursive: true);
          rootfsResolv.writeAsStringSync(resolvContent);
        }
      } catch (_) {}

      final prefs = PreferencesService();
      await prefs.init();

      // v0.3.50：版本变化时自动导出含密钥的快照到外部存储（hermes-snapshot.json），
      // 这样即使之后卸载重装，SetupWizard 完成页也能一键恢复 Key。
      // 早期版本只导 config.yaml、漏掉 .env（密钥），且文件名带版本号导致 import 读不到。
      try {
        final oldVersion = prefs.lastAppVersion;
        if (oldVersion != null && oldVersion != AppConstants.displayVersion) {
          final hasPermission = await NativeBridge.hasStoragePermission();
          if (hasPermission) {
            final path = await SnapshotService.exportSnapshot();
            // 额外保留带旧版本号的归档，便于追溯历史
            try {
              final sdcard = await NativeBridge.getExternalStoragePath();
              final archivePath = '$sdcard/Download/hermes-snapshot-$oldVersion.json';
              await File(path).copy(archivePath);
            } catch (_) {}
          }
        }
        prefs.lastAppVersion = AppConstants.displayVersion;
      } catch (_) {}

      bool setupComplete;
      try {
        setupComplete = await NativeBridge.isBootstrapComplete();
      } catch (_) {
        setupComplete = false;
      }

      // 不再在 splash 做自动修复（旧版命令错误+阻塞长达30分钟导致用户卡在启动页进不去界面）。
      // 安装/修复统一走 SetupWizard（用户手动触发），保证启动秒进界面。

      if (!mounted) return;

      if (setupComplete) {
        prefs.setupComplete = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SetupWizardScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = '${s.errorPrefix}$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/ic_launcher.png',
                width: 80,
                height: 80,
              ),
              const SizedBox(height: 24),
              Text(
                s.appName,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.appSubtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'by ${AppConstants.authorName} | ${AppConstants.orgName}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _status,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
