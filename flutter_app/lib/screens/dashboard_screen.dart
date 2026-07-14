import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../l10n/app_strings.dart';
import '../providers/gateway_provider.dart';
import '../widgets/gateway_controls.dart';
import '../widgets/status_card.dart';
import 'configure_screen.dart';
import 'onboarding_screen.dart';
import 'terminal_screen.dart';
import 'logs_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  // ── i18n helper ───────────────────────
  AppStrings s(BuildContext ctx) => AppStrings.of(ctx);

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
              s.terminalTitle,
              s.terminalDesc,
              icon: Icons.terminal,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TerminalScreen()),
              ),
            ),
            _buildActionCard(
              theme,
              s.logsTitle,
              s.logsDesc,
              icon: Icons.article,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LogsScreen()),
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
