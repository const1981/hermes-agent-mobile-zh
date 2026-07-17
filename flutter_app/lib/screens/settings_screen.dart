import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app.dart';
import '../constants.dart';
import '../l10n/app_strings.dart';
import '../providers/locale_provider.dart';
import '../services/native_bridge.dart';
import '../services/preferences_service.dart';
import '../services/snapshot_service.dart';
import '../services/update_service.dart';
import 'setup_wizard_screen.dart';
import 'logs_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _prefs = PreferencesService();
  bool _autoStart = false;
  bool _batteryOptimized = true;
  String _arch = '';
  String _prootPath = '';
  Map<String, dynamic> _status = {};
  bool _loading = true;
  bool _storageGranted = false;

  AppStrings get s => AppStrings.of(context);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _prefs.init();
    _autoStart = _prefs.autoStartGateway;

    try {
      final arch = await NativeBridge.getArch();
      final prootPath = await NativeBridge.getProotPath();
      final status = await NativeBridge.getBootstrapStatus();
      final batteryOptimized = await NativeBridge.isBatteryOptimized();
      final storageGranted = await NativeBridge.hasStoragePermission();

      setState(() {
        _batteryOptimized = batteryOptimized;
        _storageGranted = storageGranted;
        _arch = arch;
        _prootPath = prootPath;
        _status = status;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _sectionHeader(theme, s.generalSection),
                SwitchListTile(
                  title: Text(s.autoStartGateway),
                  subtitle: Text(s.autoStartGatewayDesc),
                  value: _autoStart,
                  onChanged: (value) {
                    setState(() => _autoStart = value);
                    _prefs.autoStartGateway = value;
                  },
                ),
                // ── Language selector ──
                ListTile(
                  title: Text(s.language),
                  subtitle: Text(context.watch<LocaleProvider>().isFollowingSystem
                      ? s.followSystem
                      : (context.watch<LocaleProvider>().locale.languageCode == 'zh'
                          ? s.simplifiedChinese
                          : s.english)),
                  leading: const Icon(Icons.language),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showLanguageDialog,
                ),
                ListTile(
                  title: Text(s.batteryOptimization),
                  subtitle: Text(_batteryOptimized
                      ? s.batteryOptimized
                      : s.batteryUnrestricted),
                  leading: const Icon(Icons.battery_alert),
                  trailing: _batteryOptimized
                      ? const Icon(Icons.warning, color: AppColors.statusAmber)
                      : const Icon(Icons.check_circle, color: AppColors.statusGreen),
                  onTap: () async {
                    await NativeBridge.requestBatteryOptimization();
                    final optimized = await NativeBridge.isBatteryOptimized();
                    setState(() => _batteryOptimized = optimized);
                  },
                ),
                ListTile(
                  title: Text(s.setupStorage),
                  subtitle: Text(_storageGranted
                      ? s.storageGranted
                      : s.storageNotGranted),
                  leading: const Icon(Icons.sd_storage),
                  trailing: _storageGranted
                      ? const Icon(Icons.warning_amber, color: AppColors.statusAmber)
                      : const Icon(Icons.check_circle, color: AppColors.statusGreen),
                  onTap: () async {
                    await NativeBridge.requestStoragePermission();
                    final granted = await NativeBridge.hasStoragePermission();
                    setState(() => _storageGranted = granted);
                  },
                ),
                const Divider(),
                _sectionHeader(theme, s.sysInfoSection),
                ListTile(
                  title: Text(s.architecture),
                  subtitle: Text(_arch),
                  leading: const Icon(Icons.memory),
                ),
                ListTile(
                  title: Text(s.prootPathLabel),
                  subtitle: Text(_prootPath),
                  leading: const Icon(Icons.folder),
                ),
                ListTile(
                  title: Text(s.rootfs),
                  subtitle: Text(_status['rootfsExists'] == true
                      ? s.installed
                      : s.notInstalled),
                  leading: const Icon(Icons.storage),
                ),
                ListTile(
                  title: Text(s.pythonLabel),
                  subtitle: Text(_status['pythonInstalled'] == true
                      ? s.installed
                      : s.notInstalled),
                  leading: const Icon(Icons.code),
                ),
                ListTile(
                  title: Text(s.hermesAgentLabel),
                  subtitle: Text(_status['hermesInstalled'] == true
                      ? s.installed
                      : s.notInstalled),
                  leading: const Icon(Icons.cloud),
                ),
                const Divider(),
                _sectionHeader(theme, s.maintenanceSection),
                ListTile(
                  title: Text(s.exportSnapshot),
                  subtitle: Text(s.exportSnapshotDesc),
                  leading: const Icon(Icons.upload_file),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _exportSnapshot,
                ),
                ListTile(
                  title: Text(s.importSnapshot),
                  subtitle: Text(s.importSnapshotDesc),
                  leading: const Icon(Icons.download),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _importSnapshot,
                ),
                ListTile(
                  title: Text(s.rerunSetup),
                  subtitle: Text(s.rerunSetupDesc),
                  leading: const Icon(Icons.build),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const SetupWizardScreen(),
                    ),
                  ),
                ),
                ListTile(
                  title: const Text('检查更新'),
                  subtitle: const Text('发现新版本可一键下载并安装'),
                  leading: const Icon(Icons.system_update_alt),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _checkUpdate,
                ),
                ListTile(
                  title: Text(s.cleanGarbage),
                  subtitle: Text(s.cleanGarbageDesc),
                  leading: const Icon(Icons.cleaning_services),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _cleanGarbage,
                ),
                ListTile(
                  title: const Text('查看日志'),
                  subtitle: const Text('网关与系统运行日志'),
                  leading: const Icon(Icons.article_outlined),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LogsScreen()),
                  ),
                ),
                const Divider(),
                _sectionHeader(theme, s.aboutSection),
                ListTile(
                  title: Text(s.aboutApp(AppConstants.displayVersion).split('\n')[0]),
                  subtitle: Text(s.aboutApp(AppConstants.displayVersion)),
                  leading: Icon(Icons.info_outline),
                  isThreeLine: true,
                ),
                ListTile(
                  title: Text(s.github),
                  subtitle: const Text(AppConstants.githubRepo),
                  leading: const Icon(Icons.code),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => launchUrl(
                    Uri.parse(AppConstants.githubUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                ListTile(
                  title: Text(s.contact),
                  subtitle: const Text(AppConstants.authorEmail),
                  leading: const Icon(Icons.email),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => launchUrl(
                    Uri.parse('mailto:${AppConstants.authorEmail}'),
                  ),
                ),
                ListTile(
                  title: Text(s.licenseLabel),
                  subtitle: Text(AppConstants.license),
                  leading: Icon(Icons.description),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    '${AppConstants.appName} v${AppConstants.displayVersion}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    '© 2026 ${AppConstants.authorName}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  void _showLanguageDialog() {
    final lp = context.read<LocaleProvider>();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(s.language),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String?>(
                title: Text(s.followSystem),
                value: null,
                groupValue: lp.languageCode,
                onChanged: (v) { lp.followSystem(); Navigator.pop(ctx); },
              ),
              RadioListTile<String?>(
                title: const Text('简体中文'),
                value: 'zh',
                groupValue: lp.languageCode,
                onChanged: (v) { lp.toChinese(); Navigator.pop(ctx); },
              ),
              RadioListTile<String?>(
                title: const Text('English'),
                value: 'en',
                groupValue: lp.languageCode,
                onChanged: (v) { lp.toEnglish(); Navigator.pop(ctx); },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String> _getSnapshotPath() async {
    return SnapshotService.getSnapshotPath();
  }

  Future<void> _exportSnapshot() async {
    try {
      // 配置备份 = 设置文件：config.yaml + .env（含模型 Key / 渠道密钥）。
      // 整文件夹镜像请用「系统镜像」页。集中到 SnapshotService，确保始终含 .env。
      final path = await SnapshotService.exportSnapshot();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.snapshotSaved(path))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.exportFailed(e))),
      );
    }
  }

  /// 检查更新 → 有新版弹窗（含版本说明）→ 确认后下载并跳安装器。
  Future<void> _checkUpdate() async {
    if (!mounted) return;
    late BuildContext dialogCtx;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('正在检查更新…'),
        ]),
      ),
    );
    try {
      final result = await UpdateService().checkUpdate();
      if (!mounted) return;
      Navigator.of(context).pop(); // 关闭"检查中"
      if (result.checkFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检查更新失败：${result.errorMessage ?? "未知错误"}')),
        );
        return;
      }
      if (!result.hasUpdate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已是最新版本')),
        );
        return;
      }
      final info = result.update!;
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('发现新版本 v${info.version}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('是否下载并更新？'),
                if (info.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('更新内容：',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(info.notes),
                ],
                const SizedBox(height: 8),
                Text('当前版本：v${AppConstants.displayVersion}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('稍后'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('立即更新'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          dialogCtx = ctx;
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('正在下载更新…'),
                const SizedBox(height: 16),
                StatefulBuilder(
                  builder: (c, setBar) {
                    _setProgress = setBar;
                    return LinearProgressIndicator(value: _downloadProgress);
                  },
                ),
                const SizedBox(height: 8),
                Text('${(_downloadProgress * 100).toInt()}%'),
              ],
            ),
          );
        },
      );
      _downloadProgress = 0;
      await UpdateService().downloadAndInstall(
        info,
        onProgress: (p) {
          _downloadProgress = p;
          if (_setProgress != null) _setProgress!(() {});
        },
      );
      if (!mounted) return;
      Navigator.of(dialogCtx).pop(); // 关闭下载框（系统安装器已拉起）
    } catch (e) {
      if (!mounted) return;
      try {
        Navigator.of(context).pop();
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失败：$e')),
      );
    }
  }

  double _downloadProgress = 0;
  void Function(void Function())? _setProgress;



  Future<void> _cleanGarbage() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.cleanGarbage),
        content: Text(s.cleanConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.confirm),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(s.cleaning)),
          ],
        ),
      ),
    );
    try {
      final freed = await NativeBridge.cleanGarbage();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.cleanDone(_fmtSize(freed)))),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.cleanFailed(e.toString()))),
      );
    }
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  Future<void> _importSnapshot() async {
    try {
      final path = await _getSnapshotPath();
      final file = File(path);
      if (!await file.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.noSnapshotFound(path))),
        );
        return;
      }
      final restored = await SnapshotService.importSnapshot();
      if (!restored) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('快照为空，无需恢复')),
        );
        return;
      }
      await _loadSettings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.snapshotRestored)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.importFailed(e))),
      );
    }
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
