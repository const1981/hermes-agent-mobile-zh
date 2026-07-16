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
// 本 App 无法在表单里配置，已移除微信渠道。

/// 【v0.3.35 修复】原实现是「保存并重启网关」——但首次配置时网关根本没启动，
/// 显示「重启」语义错误，且启动入口散在多处让用户困惑。
/// 现改为「只保存配置、不碰网关」：写 config.yaml + 增量合并 .env，
/// 提示用户去仪表盘（唯一启动入口）启动网关。启动动作统一收敛到仪表盘网关卡片。
Future<void> saveConfigOnly(BuildContext context) async {
  final cfg = context.read<ConfigProvider>();
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(child: Text('正在保存配置…')),
        ],
      ),
    ),
  ));
  try {
    await cfg.writeConfigFiles();
    if (!context.mounted) return;
    if (context.mounted) Navigator.of(context).pop();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('配置已保存。请到「仪表盘」点「启动网关」让配置生效。'),
          duration: Duration(seconds: 5),
        ),
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

/// 智能保存：网关未运行时保存并启动，已运行时保存并重启。
/// 仅用于「网关」管理页（与仪表盘同为网关生命周期入口），避免「重启一个不存在的网关」。
Future<void> saveAndApplyGateway(BuildContext context) async {
  final cfg = context.read<ConfigProvider>();
  final running = await NativeBridge.isGatewayRunning();
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(child: Text('正在保存配置…')),
        ],
      ),
    ),
  ));
  try {
    await cfg.writeConfigFiles();
    if (!context.mounted) return;
    if (running) {
      await NativeBridge.restartGateway();
    } else {
      await NativeBridge.startGateway();
    }
    var alive = false;
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!context.mounted) return;
      alive = await NativeBridge.isGatewayRunning();
      if (alive) break;
    }
    if (context.mounted) Navigator.of(context).pop();
    if (context.mounted) {
      final msg = alive
          ? '配置已保存，网关${running ? "已重启" : "已启动"}并运行'
          : '配置已保存，网关${running ? "重启" : "启动"}中，稍候到「仪表盘」查看状态';
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
