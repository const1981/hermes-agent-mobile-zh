import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';
import '../services/native_bridge.dart';

/// 单个渠道字段描述（把 ConfigProvider 的 getter/setter 绑定进来，组件可复用）
class ChannelField {
  final String label;
  final String hint;
  final bool obscure;
  final String Function(ConfigProvider) get;
  final void Function(ConfigProvider, String) set;
  final String? docUrl;

  const ChannelField({
    required this.label,
    required this.hint,
    required this.get,
    required this.set,
    this.obscure = false,
    this.docUrl,
  });
}

/// 单渠道卡片：开关 + 启用后展开字段。配置页与网关页共用。
class ChannelEditor extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final List<ChannelField> fields;

  const ChannelEditor({
    super.key,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onToggle,
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: enabled,
        leading: Icon(enabled ? Icons.check_circle : Icons.circle_outlined,
            color: enabled ? Colors.green : Colors.grey),
        title: Text(title, style: theme.textTheme.titleSmall),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: Switch(
          value: enabled,
          onChanged: onToggle,
        ),
        children: enabled
            ? [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: fields
                        .map((f) => _FieldTile(field: f))
                        .toList(),
                  ),
                ),
              ]
            : const [],
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  final ChannelField field;
  const _FieldTile({required this.field});

  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<ConfigProvider>();
    final value = field.get(cfg);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        obscureText: field.obscure,
        decoration: InputDecoration(
          labelText: field.label,
          hintText: field.hint,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: (field.docUrl?.isNotEmpty ?? false)
              ? IconButton(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  tooltip: '查看文档',
                  onPressed: () {
                    // 简单起见只复制/展示，真正的跳转由调用方决定
                  },
                )
              : null,
        ),
        onChanged: (v) => field.set(cfg, v),
      ),
    );
  }
}

/// 飞书字段（官方变量名 FEISHU_APP_ID / FEISHU_APP_SECRET）
final List<ChannelField> feishuFields = [
  ChannelField(
    label: 'App ID',
    hint: 'cli_xxxxxxxx',
    get: (c) => c.feishuAppId,
    set: (c, v) => c.setFeishu(appId: v),
  ),
  ChannelField(
    label: 'App Secret',
    hint: '应用密钥',
    obscure: true,
    get: (c) => c.feishuAppSecret,
    set: (c, v) => c.setFeishu(appSecret: v),
  ),
];

/// 企业微信字段（WECOM_BOT_ID / WECOM_SECRET）
final List<ChannelField> wecomFields = [
  ChannelField(
    label: 'Bot ID',
    hint: '企业微信机器人 ID',
    get: (c) => c.wecomBotId,
    set: (c, v) => c.setWecom(botId: v),
  ),
  ChannelField(
    label: 'Secret',
    hint: '应用 Secret',
    obscure: true,
    get: (c) => c.wecomSecret,
    set: (c, v) => c.setWecom(secret: v),
  ),
];

/// 钉钉字段（DINGTALK_CLIENT_ID / DINGTALK_CLIENT_SECRET）
final List<ChannelField> dingtalkFields = [
  ChannelField(
    label: 'Client ID',
    hint: '钉钉客户端 ID',
    get: (c) => c.dingtalkClientId,
    set: (c, v) => c.setDingtalk(clientId: v),
  ),
  ChannelField(
    label: 'Client Secret',
    hint: '钉钉客户端密钥',
    obscure: true,
    get: (c) => c.dingtalkClientSecret,
    set: (c, v) => c.setDingtalk(clientSecret: v),
  ),
];

// 注：个人微信需扫码登录（Hermes 后端交互式 `hermes gateway setup` 流程），
// 本 App 无法在表单里配置，已移除微信渠道。扫码对接归 sutaagent 新版实现。

/// 「保存并重启网关」：写 config.yaml + 增量合并 .env，然后重启网关让 Hermes 重新加载。
/// 对标 1Panel 的 Save and Restart Gateway。
/// 重启后轮询网关真实状态，给出准确反馈（而非一律乐观），让「保存→重启→渠道真能用」
/// 这一步对用户可见、可排查。
Future<void> saveAndRestartGateway(BuildContext context) async {
  final cfg = context.read<ConfigProvider>();
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(child: Text('正在保存配置并重启网关…')),
        ],
      ),
    ),
  ));
  try {
    await cfg.writeConfigFiles();
    final ok = await NativeBridge.restartGateway();
    if (!context.mounted) return;
    // 重启后轮询网关真实存活状态，最多等 ~8s，给准确反馈。
    var alive = false;
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!context.mounted) return;
      alive = await NativeBridge.isGatewayRunning();
      if (alive) break;
    }
    if (context.mounted) Navigator.of(context).pop();
    if (context.mounted) {
      final msg = switch ((ok, alive)) {
        (true, true) =>
          '配置已写入，网关已重启并运行，飞书等渠道现在即可在聊天里使用',
        (true, false) =>
          '配置已写入、网关重启中，稍候在聊天里试试渠道；若 30 秒后仍不可用，请到「网关」页手动重启',
        (false, _) =>
          '配置已保存，但网关重启失败，请到「网关」页手动重启',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
      );
    }
  } catch (e) {
    if (context.mounted) Navigator.of(context).pop();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    }
  }
}

// 轻量 unawaited（避免引入额外依赖）
void unawaited(Future<void>? future) {}
