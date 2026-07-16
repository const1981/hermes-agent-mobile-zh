import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../models/provider_template.dart';
import '../providers/config_provider.dart';
import '../widgets/channel_editor.dart';
import '../services/native_bridge.dart';

/// 自定义供应商在 Dropdown 里的占位 value（与模板 id 不冲突）。
const String _kCustomId = '__custom__';

/// 配置页（对标 1Panel）：顶部 TabBar [对接 | 模型 | 技能 | 设置]，下方原生表单。
/// 不再使用 NavigationRail（桌面组件，手机窄屏会水平溢出把内容挤出视口→白屏）。
class ConfigureScreen extends StatefulWidget {
  const ConfigureScreen({super.key});

  @override
  State<ConfigureScreen> createState() => _ConfigureScreenState();
}

class _ConfigureScreenState extends State<ConfigureScreen> {
  @override
  void initState() {
    super.initState();
    // 进入配置页即从 .env 拉取真实已配状态，避免显示空白
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cfg = context.read<ConfigProvider>();
      // 同时还原 .env（密钥/渠道）与 config.yaml（供应商）：否则重开配置页
      // 下拉仍是默认 deepseek，点保存会把已配好的供应商覆盖损坏。
      cfg.loadEnv();
      cfg.loadModelConfig();
    });
  }

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
              Tab(icon: Icon(Icons.forum_outlined), text: '对接'),
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

/// 对接：飞书 / 企业微信 / 钉钉（就地配 Key，保存即重启网关）
/// 注：个人微信需扫码登录（Hermes 后端交互式流程），本 App 暂不支持，已移除。
class _ChannelPanel extends StatelessWidget {
  const _ChannelPanel();

  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<ConfigProvider>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text('配置沟通渠道（飞书/企微/钉钉），开启后保存会自动重启网关生效。',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
        ChannelEditor(
          title: '飞书',
          subtitle: '企业自建应用（FEISHU_APP_ID）',
          enabled: cfg.feishuEnabled,
          onToggle: (v) => cfg.setFeishu(enabled: v),
          fields: feishuFields,
        ),
        ChannelEditor(
          title: '企业微信',
          subtitle: '企业微信机器人（WECOM_BOT_ID）',
          enabled: cfg.wecomEnabled,
          onToggle: (v) => cfg.setWecom(enabled: v),
          fields: wecomFields,
        ),
        ChannelEditor(
          title: '钉钉',
          subtitle: '钉钉客户端（DINGTALK_CLIENT_ID）',
          enabled: cfg.dingtalkEnabled,
          onToggle: (v) => cfg.setDingtalk(enabled: v),
          fields: dingtalkFields,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => saveAndRestartGateway(context),
            icon: const Icon(Icons.save),
            label: const Text('保存并重启网关'),
          ),
        ),
        const SizedBox(height: 12),
        const Text('保存后会写入 ~/.hermes/.env 并自动重启网关，飞书等渠道即可在聊天里使用。',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

/// 模型：下拉选框选供应商 + 只填 Key
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
    // 取一次 selectedTemplate，避免多处 ! 强解包在 null 上崩溃
    final tmpl = cfg.selectedTemplate;
    final currentValue = cfg.useCustomProvider ? _kCustomId : cfg.providerId;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(icon: '🤖', title: '模型供应商'),
        const SizedBox(height: 8),
        // 下拉选框：常用厂商全收纳（可滚动），不再铺成卡片网格
        DropdownButtonFormField<String>(
          value: currentValue,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: '选择供应商',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            for (final t in kProviderTemplates)
              DropdownMenuItem(
                value: t.id,
                child: Text('${t.icon} ${t.name}'),
              ),
            const DropdownMenuItem(
              value: _kCustomId,
              child: Text('➕ 自定义'),
            ),
          ],
          onChanged: (v) {
            if (v == _kCustomId) {
              cfg.setCustomProvider();
            } else if (v != null) {
              cfg.selectProvider(v);
            }
          },
        ),
        const SizedBox(height: 16),
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
                  items: (tmpl?.models ?? [cfg.model])
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) cfg.setModel(v);
                  },
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
          label: tmpl?.keyLabel ?? 'API Key',
          hint: tmpl?.keyHint ?? 'sk-...',
          value: cfg.apiKey,
          onChanged: cfg.setApiKey,
          obscure: true,
          suffix: _docButton(tmpl),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => saveAndRestartGateway(context),
                icon: const Icon(Icons.save),
                label: const Text('保存并重启网关'),
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
        const Text('选好供应商、填 Key → 保存并重启网关，无需进命令行。',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  /// 「获取 Key」图标按钮：docUrl 为空串或非空才显示，避免 Uri.parse('') 崩溃
  Widget? _docButton(ProviderTemplate? tmpl) {
    final doc = tmpl?.docUrl;
    if (doc == null || doc.isEmpty) return null;
    return IconButton(
      icon: const Icon(Icons.open_in_new, size: 18),
      tooltip: '获取 Key',
      onPressed: () => launchUrl(
        Uri.parse(doc),
        mode: LaunchMode.externalApplication,
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
        const _SkillInstaller(),
      ],
    );
  }
}

/// 安装技能：粘贴技能地址（URL 或本地路径）一键安装。
/// 注：搜索+一键安装的技能市场为其他独立产品能力（未来可能收费），
/// 这里老版本只提供手动安装入口，保持免费。
class _SkillInstaller extends StatefulWidget {
  const _SkillInstaller();

  @override
  State<_SkillInstaller> createState() => _SkillInstallerState();
}

class _SkillInstallerState extends State<_SkillInstaller> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _result;
  bool _ok = false;

  Future<void> _install() async {
    final input = _ctrl.text.trim();
    if (input.isEmpty) return;
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final out = await NativeBridge.runInProot(
        'hermes skills install "$input"',
        timeout: 300,
      );
      final trimmed = out.trim();
      setState(() {
        _ok = true;
        _result = trimmed.isNotEmpty ? trimmed : '安装命令已执行（无输出）。';
      });
    } catch (e) {
      setState(() {
        _ok = false;
        _result = '安装失败：$e';
      });
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(icon: '📥', title: '安装技能'),
            const SizedBox(height: 8),
            const Text(
              '粘贴技能地址（URL 或本地路径），或先从别处下载到手机再粘贴路径，点安装即可。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      hintText: 'https://... 或 /storage/emulated/0/.../skill',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _install,
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('安装'),
                ),
              ],
            ),
            if (_result != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _ok
                      ? theme.colorScheme.primary.withOpacity(0.1)
                      : theme.colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _result!,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
          ],
        ),
      ),
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
            const SizedBox(height: 4),
            Text('联系： ${AppConstants.authorEmail}',
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
