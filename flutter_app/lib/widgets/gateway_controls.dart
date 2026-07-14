import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app.dart';
import '../constants.dart';
import '../l10n/app_strings.dart';
import '../models/gateway_state.dart';
import '../providers/gateway_provider.dart';
import '../screens/logs_screen.dart';

class GatewayControls extends StatelessWidget {
  const GatewayControls({super.key});

  // ── i18n helper ───────────────────────
  AppStrings s(BuildContext ctx) => AppStrings.of(ctx);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<GatewayProvider>(
      builder: (context, provider, _) {
        final state = provider.state;
        final s = AppStrings.of(context);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.gateway,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _statusBadge(state.status, theme),
                  ],
                ),
                const SizedBox(height: 8),
                if (state.isRunning) ...[
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          state.dashboardUrl ?? AppConstants.gatewayUrl,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: s.copyUrl,
                        onPressed: () {
                          final url = state.dashboardUrl ?? AppConstants.gatewayUrl;
                          Clipboard.setData(ClipboardData(text: url));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('URL copied to clipboard'), // keep short
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 18),
                        tooltip: s.openDashboard,
                        onPressed: () {
                          final url = Uri.tryParse(state.dashboardUrl ?? AppConstants.gatewayUrl);
                          if (url != null) {
                            launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ],
                  ),
                ],
                if (state.errorMessage != null)
                  Text(
                    state.errorMessage!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (state.isStopped || state.status == GatewayStatus.error)
                      FilledButton.icon(
                        onPressed: () => provider.start(),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Gateway'), // keep short for button
                      ),
                    if (state.isRunning || state.status == GatewayStatus.starting)
                      OutlinedButton.icon(
                        onPressed: () => provider.stop(),
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop Gateway'), // keep short for button
                      ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LogsScreen()),
                      ),
                      icon: const Icon(Icons.article_outlined),
                      label: Text(s.viewLogs),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusBadge(GatewayStatus status, ThemeData theme) {
    Color color;
    String label;
    IconData icon;
    final s = AppStrings.of(context); // need BuildContext here

    switch (status) {
      case GatewayStatus.running:
        color = AppColors.statusGreen;
        label = s.runningStatus;
        icon = Icons.check_circle_outline;
      case GatewayStatus.starting:
        color = AppColors.statusAmber;
        label = s.startingStatus;
        icon = Icons.hourglass_top;
      case GatewayStatus.error:
        color = AppColors.statusRed;
        label = s.errorStatus;
        icon = Icons.error_outline;
      case GatewayStatus.stopped:
        color = AppColors.statusGrey;
        label = s.stoppedStatus;
        icon = Icons.circle_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
