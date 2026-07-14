import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../l10n/app_strings.dart';
import '../models/setup_state.dart';
import '../providers/setup_provider.dart';
import '../services/native_bridge.dart';
import '../services/install_log.dart';
import '../widgets/progress_step.dart';
import 'dashboard_screen.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  bool _started = false;

  AppStrings get s => AppStrings.of(context);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Consumer<SetupProvider>(
          builder: (context, provider, _) {
            final state = provider.state;

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  Image.asset(
                    'assets/ic_launcher.png',
                    width: 64,
                    height: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.setupHermesAgent,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _started
                        ? s.setupProgressDesc
                        : s.setupInitialDesc,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: _buildSteps(state, theme),
                  ),
                  if (provider.logLines.isNotEmpty && !state.isComplete) ...[
                    const SizedBox(height: 12),
                    Container(
                      height: 130,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        reverse: true,
                        itemCount: provider.logLines.length,
                        itemBuilder: (_, i) => Text(
                          provider.logLines[i],
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                  ],
                  if (state.hasError) ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline, color: theme.colorScheme.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Text(
                                  state.error ?? s.unknownError,
                                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _showLog(context),
                        icon: const Icon(Icons.article_outlined, size: 18),
                        label: const Text('查看完整安装日志'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (state.isComplete)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _goToDashboard(context),
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(s.goToDashboard),
                      ),
                    )
                  else if (!_started || state.hasError)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: provider.isRunning
                            ? null
                            : () async {
                                setState(() => _started = true);
                                await _ensurePermissions();
                                provider.runSetup();
                              },
                        icon: const Icon(Icons.download),
                        label: Text(_started ? s.retrySetup : s.beginSetup),
                      ),
                    ),
                  if (!_started) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        s.storageHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'by ${AppConstants.authorName} | ${AppConstants.orgName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSteps(SetupState state, ThemeData theme) {
    final s = AppStrings.of(context);
    final steps = [
      (1, s.downloadUbuntuRootfs, SetupStep.downloadingRootfs),
      (2, s.extractRootfs, SetupStep.extractingRootfs),
      (3, s.installPython, SetupStep.installingPython),
      (4, s.installHermesAgent, SetupStep.installingHermesAgent),
      (5, s.configureEnvironment, SetupStep.configuringEnvironment),
    ];

    return ListView(
      children: [
        for (final (num, label, step) in steps)
          ProgressStep(
            stepNumber: num,
            label: state.step == step ? state.message : label,
            isActive: state.step == step,
            isComplete: state.stepNumber > step.index || state.isComplete,
            hasError: state.hasError && state.step == step,
            progress: state.step == step ? state.progress : null,
          ),
        if (state.isComplete) ...[
          const ProgressStep(
            stepNumber: 6,
            label: 'Setup complete!', // keep English for brand feel, or use s.setupComplete
            isComplete: true,
          ),
        ],
      ],
    );
  }

  void _goToDashboard(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  /// 进安装向导第一屏就开始申请所有需要的权限（存储 + 电池白名单）。
  /// 通知权限已在 App 启动时自动申请。
  Future<void> _ensurePermissions() async {
    try {
      final hasStorage = await NativeBridge.hasStoragePermission();
      if (!hasStorage) await NativeBridge.requestStoragePermission();
    } catch (_) {}
    try {
      final batteryOpt = await NativeBridge.isBatteryOptimized();
      if (batteryOpt) await NativeBridge.requestBatteryOptimization();
    } catch (_) {}
  }

  /// 弹出完整安装日志（失败排查用）
  Future<void> _showLog(BuildContext context) async {
    final log = await InstallLog.readAll();
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('安装日志'),
        content: SizedBox(
          width: double.maxFinite,
          height: 420,
          child: SingleChildScrollView(
            child: SelectableText(log.isEmpty ? '（暂无日志）' : log),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
