import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_strings.dart';
import '../providers/gateway_provider.dart';
import '../services/native_bridge.dart';
import '../widgets/gateway_controls.dart';
import '../widgets/status_card.dart';
import 'configure_screen.dart';
import 'onboarding_screen.dart';
import 'chat_screen.dart';
import 'gateway_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  bool _needsConfig = false;

  @override
  void initState() {
    super.initState();
    _loadGuidance();
  }

  // 装完 Hermes 后，若模型或通讯渠道还没配齐，给出明确引导（闭环：装完→设模型→设渠道）。
  Future<void> _loadGuidance() async {
    try {
      final status = await NativeBridge.getBootstrapStatus();
      final hermesInstalled = status['hermesInstalled'] == true;
      bool needs = false;
      if (hermesInstalled) {
        final cfg = await NativeBridge.readRootfsFile('root/.hermes/config.yaml');
        final env = await NativeBridge.readRootfsFile('root/.hermes/.env');
        final hasModel = cfg != null &&
            cfg.contains(RegExp(r'base_url:\s*(?![\$\{])')) &&
            cfg.contains(RegExp(r'default:\s*\S+'));
        final channelKeys = [
          'FEISHU_APP_ID',
          'WECOM_BOT_ID',
          'DINGTALK_CLIENT_ID',
          'TELEGRAM_BOT_TOKEN',
          'QQ_APP_ID',
        ];
        final hasChannel = env != null &&
            channelKeys.any((k) => RegExp('$k=\\s*\\S+').hasMatch(env));
        needs = !hasModel || !hasChannel;
      }
      if (mounted) {
        setState(() {
          _needsConfig = needs;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_needsConfig && !_loading) _buildGuidanceBanner(context),
            const GatewayControls(),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                s.quickActions,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            _buildActionCard(
              theme,
              s.onboardingTitle,
              s.onboardingDesc,
              icon: Icons.rocket_launch,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OnboardingScreen()),
              ),
            ),
            _buildActionCard(
              theme,
              s.configureTitle,
              s.configureDesc,
              icon: Icons.tune,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConfigureScreen()),
              ),
            ),
            _buildActionCard(
              theme,
              '对话',
              '与 AI 主 Agent 聊天（流式回复）',
              icon: Icons.chat_bubble,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              ),
            ),
            _buildActionCard(
              theme,
              '网关',
              '渠道对接与网关状态（飞书/企微/钉钉）',
              icon: Icons.cloud,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GatewayScreen()),
              ),
            ),
            _buildActionCard(
              theme,
              '高级设置',
              '环境维护：导出/导入快照、重新初始化、清理垃圾',
              icon: Icons.settings_applications,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                s.statusSection,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Consumer<GatewayProvider>(
              builder: (context, provider, _) {
                return                 _buildStatusCard(
                  theme,
                  s.gateway,
                  provider.statusLabel,
                  icon: provider.isRunning ? Icons.cloud_done : Icons.cloud_off,
                  color: provider.statusColor,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidanceBanner(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '安装完成！下一步配置',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Hermes 已装好。现在去设置大模型（GLM/DeepSeek 等）和通讯渠道（飞书/企微/钉钉），才能开始对话。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConfigureScreen()),
              ),
              icon: const Icon(Icons.tune),
              label: Text(s.configureTitle),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    ThemeData theme,
    String title,
    String subtitle, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildStatusCard(
    ThemeData theme,
    String title,
    String value, {
    required IconData icon,
    required Color color,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return StatusCard(
      title: title,
      value: value,
      icon: icon,
      iconColor: color,
      trailing: trailing,
      onTap: onTap,
    );
  }
}
