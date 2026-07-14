import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../l10n/app_strings.dart';
import '../models/provider_template.dart';
import '../providers/config_provider.dart';
import '../services/native_bridge.dart';

/// 配置页（对标 1Panel）：顶部 TabBar [频道 | 模型 | 技能 | 设置]，下方原生表单。
/// 不再使用 NavigationRail（桌面组件，手机窄屏会水平溢出把内容挤出视口→白屏）。
class ConfigureScreen extends StatelessWidget {
  const ConfigureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: 1, // 默认停在「模型」
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hermes 配置'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          bottom: const TabBar(
            isScrollable: false,
            tabs: [
              Tab(icon: Icon(Icons.forum_outlined), text: '频道'),
              Tab(icon: Icon(Icons.hub_outlined), text: '模型'),
              Tab(icon: Icon(Icons.extension_outlined), text: '技能'),
              Tab(icon: Icon(Icons.settings_outlined), text: '设置'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ChannelPanel(),
            _ModelPanel(),
            _SkillPanel(),
            _SettingPanel(),
          ],
        ),
      ),
    );
  }
}

/// 频道：微信 / 飞书 / Telegram 等
class _ChannelPanel extends StatelessWidget {
  const _ChannelPanel();

  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<ConfigProvider>();
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(icon: '💬', title: '微信'),
        SwitchListTile(
          title: const Text('启用微信对接'),
          subtitle: const Text('扫码后自动重启容器'),
          value: cfg.wechatEnabled,
          onChanged: (v) => cfg.setWechat(enabled: v),
        ),
        if (cfg.wechatEnabled) ...[
          _TextFieldTile(
            label: 'Token',
            hint: '微信公众平台 Token',
            value: cfg.wechatToken,
            onChanged: (v) => cfg.setWechat(token: v),
            obscure: true,
          ),
          _TextFieldTile(
            label: 'EncodingAESKey',
            hint: '消息加密密钥',
            value: cfg.wechatEncodingAesKey,
            onChanged: (v) => cfg.setWechat(aesKey: v),
            obscure: true,
          ),
        ],
        const Divider(height: 24),
        _SectionTitle(icon: '📋', title: '飞书'),
        SwitchListTile(
          title: const Text('启用飞书对接'),
          subtitle: const Text('企业自建应用 Webhook'),
          value: cfg.feishuEnabled,
          onChanged: (v) => cfg.setFeishu(enabled: v),
        ),
        if (cfg.feishuEnabled) ...[
          _TextFieldTile(
            label: 'App ID',
            hint: 'cli_xxx',
            value: cfg.feishuAppId,
            onChanged: (v) => cfg.setFeishu(appId: v),
          ),
          _TextFieldTile(
            label: 'App Secret',
            hint: '应用密钥',
            value: cfg.feishuAppSecret,
            onChanged: (v) => cfg.setFeishu(appSecret: v),
            obscure: true,
          ),
        ],
        const Divider(height: 24),
        _SectionTitle(icon: '✈️', title: 'Telegram'),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('在 .env 中配置 TELEGRAM_BOT_TOKEN 后重启网关即可。',
              style: TextStyle(color: Colors.grey)),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              final cfg = context.read<ConfigProvider>();
              try {
                await NativeBridge.writeRootfsFile(
                    'root/.hermes/config.yaml', cfg.toConfigYaml());
                await NativeBridge.writeRootfsFile(
                    'root/.hermes/.env', cfg.toEnv());
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('频道配置已保存，重启网关生效')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('保存失败：$e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.save),
            label: const Text('保存配置'),
          ),
        ),
        const SizedBox(height: 12),
        const Text('配置保存后需重启网关生效（设置页 → 重启网关）。',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

/// 模型：供应商卡片 + 只填 Key
class _ModelPanel extends StatefulWidget {
  const _ModelPanel();

  @override
  State<_ModelPanel> createState() => _ModelPanelState();
}

class _ModelPanelState extends State<_ModelPanel> {
  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<ConfigProvider>();
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(icon: '🤖', title: '选择供应商'),
        const SizedBox(height: 8),
        // 供应商网格（卡片）
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.6,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final t in kProviderTemplates)
              _ProviderCard(
                template: t,
                selected: !cfg.useCustomProvider && cfg.providerId == t.id,
                onTap: () => cfg.selectProvider(t.id),
              ),
            // 自定义
            _ProviderCard(
              template: const ProviderTemplate(
                id: 'custom',
                name: '自定义',
                icon: '➕',
                baseUrl: '',
                defaultModel: '',
                models: const [],
                description: '手动填写全部',
              ),
              selected: cfg.useCustomProvider,
              onTap: () => cfg.setCustomProvider(),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // 表单
        if (cfg.useCustomProvider) ...[
          _TextFieldTile(
            label: 'Base URL',
            hint: 'https://your-endpoint/v1',
            value: cfg.baseUrl,
            onChanged: cfg.setBaseUrl,
          ),
          _TextFieldTile(
            label: '模型名称',
            hint: 'model-name',
            value: cfg.model,
            onChanged: cfg.setModel,
          ),
        ] else ...[
          // 预设供应商：展示自动带好的地址 + 模型下拉
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Base URL（已自动填入）',
                    style: theme.textTheme.labelSmall),
                const SizedBox(height: 4),
                Text(cfg.baseUrl, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                Text('模型', style: theme.textTheme.labelSmall),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: cfg.model,
                  isExpanded: true,
                  items: (cfg.selectedTemplate?.models ?? [cfg.model])
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => cfg.setModel(v!),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        // API Key（唯一需手填）
        _TextFieldTile(
          label: cfg.selectedTemplate?.keyLabel ?? 'API Key',
          hint: cfg.selectedTemplate?.keyHint ?? 'sk-...',
          value: cfg.apiKey,
          onChanged: cfg.setApiKey,
          obscure: true,
          suffix: cfg.selectedTemplate?.docUrl != null
              ? IconButton(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  tooltip: '获取 Key',
                  onPressed: () => launchUrl(
                    Uri.parse(cfg.selectedTemplate!.docUrl!),
                    mode: LaunchMode.externalApplication,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  final cfg = context.read<ConfigProvider>();
                  try {
                    await NativeBridge.writeRootfsFile(
                        'root/.hermes/config.yaml', cfg.toConfigYaml());
                    await NativeBridge.writeRootfsFile(
                        'root/.hermes/.env', cfg.toEnv());
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('配置已写入 ~/.hermes/config.yaml，重启网关生效')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('保存失败：$e')),
                    );
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text('保存配置'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () async {
                  final cfg = context.read<ConfigProvider>();
                  if (cfg.apiKey.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请先填写 API Key')),
                    );
                    return;
                  }
                  try {
                    final out = await NativeBridge.runInProot(
                      'curl -s -o /dev/null -w "%{http_code}" -m 20 "${cfg.baseUrl}/models" '
                      '-H "Authorization: Bearer ${cfg.apiKey}"',
                      timeout: 30,
                    );
                    if (!mounted) return;
                    final code = out.trim();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(code == '200'
                            ? '连通正常（HTTP 200），Key 有效'
                            : '测试返回：$code（非 200 请检查 Key/地址）'),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('验证失败：$e')),
                    );
                  }
                },
                icon: const Icon(Icons.verified),
                label: const Text('验证连通性'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('选好供应商、填 Key → 保存，无需进命令行。',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final ProviderTemplate template;
  final bool selected;
  final VoidCallback onTap;

  const _ProviderCard({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text(template.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  template.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selected) Icon(Icons.check_circle, size: 16, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// 技能：开关
class _SkillPanel extends StatelessWidget {
  const _SkillPanel();

  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<ConfigProvider>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(icon: '🧩', title: '功能技能'),
        SwitchListTile(
          title: const Text('联网搜索'),
          subtitle: const Text('允许 Agent 实时检索网络'),
          value: cfg.skillWebSearch,
          onChanged: (v) => cfg.setSkill(webSearch: v),
        ),
        SwitchListTile(
          title: const Text('代码执行'),
          subtitle: const Text('允许运行生成的代码'),
          value: cfg.skillCodeRun,
          onChanged: (v) => cfg.setSkill(codeRun: v),
        ),
        SwitchListTile(
          title: const Text('长期记忆'),
          subtitle: const Text('跨会话记住上下文'),
          value: cfg.skillMemory,
          onChanged: (v) => cfg.setSkill(memory: v),
        ),
      ],
    );
  }
}

/// 设置：通用
class _SettingPanel extends StatelessWidget {
  const _SettingPanel();

  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<ConfigProvider>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(icon: '⚙️', title: '通用设置'),
        SwitchListTile(
          title: const Text('启动后自动开网关'),
          value: cfg.autoStartGateway,
          onChanged: (v) => cfg.setSettings(autoStart: v),
        ),
        ListTile(
          title: const Text('最大 Token 数'),
          subtitle: Text('${cfg.maxTokens}'),
          trailing: SizedBox(
            width: 160,
            child: Slider(
              value: cfg.maxTokens.toDouble(),
              min: 1024,
              max: 16384,
              divisions: 15,
              onChanged: (v) => cfg.setSettings(maxTokens: v.round()),
            ),
          ),
        ),
        const Divider(height: 24),
        const _AboutCard(),
      ],
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${AppConstants.appName} v${AppConstants.version}',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('© 2026 ${AppConstants.authorName}',
                style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.titleSmall),
      ],
    );
  }
}

class _TextFieldTile extends StatelessWidget {
  final String label;
  final String hint;
  final String value;
  final ValueChanged<String> onChanged;
  final bool obscure;
  final Widget? suffix;

  const _TextFieldTile({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.obscure = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          suffixIcon: suffix,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
