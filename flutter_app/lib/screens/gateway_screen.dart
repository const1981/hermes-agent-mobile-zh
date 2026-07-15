import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';
import '../services/native_bridge.dart';
import '../widgets/channel_editor.dart';

/// 网关页：显示网关运行状态 + 飞书/企微/钉钉 三渠道「已配/未配」与就地配 Key。
/// 对标 1Panel 的「聊天渠道」页：渠道配置与网关状态集中管理，保存即重启网关。
class GatewayScreen extends StatefulWidget {
  const GatewayScreen({super.key});

  @override
  State<GatewayScreen> createState() => _GatewayScreenState();
}

class _GatewayScreenState extends State<GatewayScreen> {
  bool _running = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    // 进入页面即从 .env 拉取真实已配状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ConfigProvider>().loadEnv();
    });
  }

  Future<void> _refresh() async {
    setState(() => _checking = true);
    try {
      _running = await NativeBridge.isGatewayRunning();
    } catch (_) {
      _running = false;
    }
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<ConfigProvider>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('网关'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: '刷新状态',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 网关运行状态
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _running ? Icons.cloud_done : Icons.cloud_off,
                    color: _running ? Colors.green : Colors.grey,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('网关状态', style: theme.textTheme.labelSmall),
                        const SizedBox(height: 2),
                        Text(
                          _checking
                              ? '检测中…'
                              : (_running ? '运行中' : '未运行'),
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _checking
                        ? null
                        : () async {
                            if (_running) {
                              await NativeBridge.restartGateway();
                            } else {
                              await NativeBridge.startGateway();
                            }
                            await Future.delayed(const Duration(seconds: 2));
                            await _refresh();
                          },
                    child: Text(_running ? '重启网关' : '启动网关'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('沟通渠道', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          ChannelEditor(
            title: '飞书',
            subtitle: cfg.feishuEnabled ? '已配置' : '未配置',
            enabled: cfg.feishuEnabled,
            onToggle: (v) => cfg.setFeishu(enabled: v),
            fields: feishuFields,
          ),
          ChannelEditor(
            title: '企业微信',
            subtitle: cfg.wecomEnabled ? '已配置' : '未配置',
            enabled: cfg.wecomEnabled,
            onToggle: (v) => cfg.setWecom(enabled: v),
            fields: wecomFields,
          ),
          ChannelEditor(
            title: '钉钉',
            subtitle: cfg.dingtalkEnabled ? '已配置' : '未配置',
            enabled: cfg.dingtalkEnabled,
            onToggle: (v) => cfg.setDingtalk(enabled: v),
            fields: dingtalkFields,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => saveAndRestartGateway(context),
              icon: const Icon(Icons.save),
              label: const Text('保存并重启网关'),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '开启渠道并填好 Key → 保存并重启网关，即可在飞书/企微/钉钉里直接和 Agent 对话。',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
