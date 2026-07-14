import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app.dart';
import '../constants.dart';
import '../l10n/app_strings.dart';
import '../providers/locale_provider.dart';
import '../services/native_bridge.dart';
import '../services/preferences_service.dart';
import 'setup_wizard_screen.dart';

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
                const Divider(),
                _sectionHeader(theme, s.aboutSection),
                ListTile(
                  title: Text(s.aboutApp(AppConstants.version).split('\n')[0]),
                  subtitle: Text(s.aboutApp(AppConstants.version)),
                  leading: Icon(Icons.info_outline),
                  isThreeLine: true,
                ),
                ListTile(
                  title: Text(s.github),
                  subtitle: const Text('nousresearch/hermes-agent-mobile'),
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
    final hasPermission = await NativeBridge.hasStoragePermission();
    if (hasPermission) {
      final sdcard = await NativeBridge.getExternalStoragePath();
      final downloadDir = Directory('$sdcard/Download');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return '$sdcard/Download/hermes-snapshot.json';
    }
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/hermes-snapshot.json';
  }

  Future<void> _exportSnapshot() async {
    try {
      final hermesConfig = await NativeBridge.readRootfsFile('root/.hermes/config.yaml');
      final snapshot = {
        'version': AppConstants.version,
        'timestamp': DateTime.now().toIso8601String(),
        'hermesConfig': hermesConfig,
        'autoStart': _prefs.autoStartGateway,
      };
      final path = await _getSnapshotPath();
      await File(path).writeAsString(const JsonEncoder.withIndent('  ').convert(snapshot));
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
      final content = await file.readAsString();
      final snapshot = jsonDecode(content) as Map<String, dynamic>;
      final hermesConfig = snapshot['hermesConfig'] as String?;
      if (hermesConfig != null) {
        await NativeBridge.writeRootfsFile('root/.hermes/config.yaml', hermesConfig);
      }
      if (snapshot['autoStart'] != null) {
        _prefs.autoStartGateway = snapshot['autoStart'] as bool;
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
