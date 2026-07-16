import 'package:flutter/material.dart';
import '../models/provider_template.dart';
import '../services/native_bridge.dart';

/// Hermes 真实渠道变量名（官方文档 hermesagent.org.cn，无 HERMES_ 前缀，写 ~/.hermes/.env）
/// 飞书:    FEISHU_APP_ID / FEISHU_APP_SECRET
/// 企微:    WECOM_BOT_ID / WECOM_SECRET
/// 钉钉:    DINGTALK_CLIENT_ID / DINGTALK_CLIENT_SECRET
/// （微信个人号需扫码登录，无法表单配置，已移除）
/// 模型密钥: HERMES_API_KEY
class ConfigProvider extends ChangeNotifier {
  ConfigProvider() {
    _loadFromPrefs();
  }

  // ── 模型配置 ──────────────────────────────
  String _providerId = 'deepseek';
  String _apiKey = '';
  String _baseUrl = kProviderTemplates.first.baseUrl;
  String _model = kProviderTemplates.first.defaultModel;
  bool _useCustomProvider = false;

  // ── 渠道配置（飞书/企微/钉钉；个人微信需扫码，已移除） ──
  bool _feishuEnabled = false;
  String _feishuAppId = '';
  String _feishuAppSecret = '';

  bool _wecomEnabled = false;
  String _wecomBotId = '';
  String _wecomSecret = '';

  bool _dingtalkEnabled = false;
  String _dingtalkClientId = '';
  String _dingtalkClientSecret = '';

  // 注：个人微信需扫码登录（Hermes 后端交互式流程），本 App 无法表单配置，已移除微信渠道。

  // ── 技能开关 ──────────────────────────────
  bool _skillWebSearch = false;
  bool _skillCodeRun = true;
  bool _skillMemory = true;

  // ── 设置 ──────────────────────────────────
  bool _autoStartGateway = true;
  int _maxTokens = 4096;

  /// 受本 App 管理的 .env 键（保存时只动这些，其余键原样保留，避免丢数据）
  static const Set<String> managedKeys = {
    'HERMES_API_KEY',
    'XIAOMI_API_KEY',
    'FEISHU_APP_ID',
    'FEISHU_APP_SECRET',
    'WECOM_BOT_ID',
    'WECOM_SECRET',
    'DINGTALK_CLIENT_ID',
    'DINGTALK_CLIENT_SECRET',
  };

  // ── 持久化：从 ~/.hermes/.env 读取真实配置 ──
  void _loadFromPrefs() {
    // 真值来源是 proot 内的 .env；进入配置/网关页时再 loadEnv() 拉取最新。
    // 这里保留默认，避免构造期异步。
  }

  /// 从 ~/.hermes/.env 读取并填充渠道/模型状态（网关页、配置页 init 时调用）
  Future<void> loadEnv() async {
    try {
      final content = await NativeBridge.readRootfsFile('root/.hermes/.env');
      if (content == null || content.isEmpty) return;
      final map = _parseEnv(content);
      _feishuEnabled =
          map.containsKey('FEISHU_APP_ID') && (map['FEISHU_APP_ID']?.isNotEmpty ?? false);
      _feishuAppId = map['FEISHU_APP_ID'] ?? '';
      _feishuAppSecret = map['FEISHU_APP_SECRET'] ?? '';
      _wecomEnabled =
          map.containsKey('WECOM_BOT_ID') && (map['WECOM_BOT_ID']?.isNotEmpty ?? false);
      _wecomBotId = map['WECOM_BOT_ID'] ?? '';
      _wecomSecret = map['WECOM_SECRET'] ?? '';
      _dingtalkEnabled = map.containsKey('DINGTALK_CLIENT_ID') &&
          (map['DINGTALK_CLIENT_ID']?.isNotEmpty ?? false);
      _dingtalkClientId = map['DINGTALK_CLIENT_ID'] ?? '';
      _dingtalkClientSecret = map['DINGTALK_CLIENT_SECRET'] ?? '';
      if (map.containsKey('HERMES_API_KEY')) _apiKey = map['HERMES_API_KEY'] ?? '';
      if (map.containsKey('XIAOMI_API_KEY')) {
        final v = map['XIAOMI_API_KEY'] ?? '';
        if (v.isNotEmpty) _apiKey = v;
      }
      notifyListeners();
    } catch (_) {
      // 读不到就保留默认，不阻塞 UI
    }
  }

  static Map<String, String> _parseEnv(String content) {
    final map = <String, String>{};
    for (final line in content.split('\n')) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      final idx = t.indexOf('=');
      if (idx < 0) continue;
      final k = t.substring(0, idx).trim();
      final v = t.substring(idx + 1).trim();
      if (k.isNotEmpty) map[k] = v;
    }
    return map;
  }

  /// 解析 config.yaml 的 model: 块，返回 {provider, default, base_url, api_key(去 ${})}
  static Map<String, String>? _parseModelBlock(String yaml) {
    final lines = yaml.split('\n');
    final map = <String, String>{};
    var inModel = false;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed == 'model:') {
        inModel = true;
        continue;
      }
      if (inModel) {
        // 遇到不缩进的同级/高级键 → model 块结束
        if (trimmed.isNotEmpty && !line.startsWith(' ') && !line.startsWith('\t')) {
          break;
        }
        final idx = trimmed.indexOf(':');
        if (idx < 0) continue;
        final k = trimmed.substring(0, idx).trim();
        var v = trimmed.substring(idx + 1).trim();
        // 去掉 YAML 双引号
        if (v.startsWith('"') && v.endsWith('"')) {
          v = v.substring(1, v.length - 1);
        }
        if (k.isNotEmpty) map[k] = v;
      }
    }
    return inModel ? map : null;
  }

  /// 从 config.yaml 还原模型供应商状态（provider/baseUrl/model）。
  ///
  /// 必须和 loadEnv() 一起在进配置页时调用：否则重开配置页下拉仍是默认的
  /// deepseek，用户若在「对接(飞书)」页点「保存并重启网关」（共享写盘路径），
  /// 会把已配好的供应商（尤其 MiMo）覆盖成 deepseek、甚至把 XIAOMI_API_KEY
  /// 写成 HERMES_API_KEY → 配置损坏、网关无法鉴权。这是「飞书/模型配置文件冲突」的根因。
  Future<void> loadModelConfig() async {
    try {
      final content = await NativeBridge.readRootfsFile('root/.hermes/config.yaml');
      if (content == null || content.isEmpty) return;
      final model = _parseModelBlock(content);
      if (model == null) return;
      final provider = model['provider'];
      final defaultModel = model['default'] ?? '';
      final baseUrl = model['base_url'] ?? '';
      if (provider == 'custom') {
        _useCustomProvider = true;
        _baseUrl = baseUrl;
        _model = defaultModel;
      } else if (provider != null) {
        final tpl = kProviderTemplates
            .where((t) => t.hermesProvider == provider || t.id == provider)
            .firstOrNull;
        if (tpl != null) {
          _providerId = tpl.id;
          _useCustomProvider = false;
          _baseUrl = baseUrl.isNotEmpty ? baseUrl : tpl.baseUrl;
          _model = defaultModel.isNotEmpty ? defaultModel : tpl.defaultModel;
        } else {
          // 未知 provider：退回自定义，至少保住 base_url/model
          _useCustomProvider = true;
          _baseUrl = baseUrl;
          _model = defaultModel;
        }
      }
      notifyListeners();
    } catch (_) {
      // 读不到就保留默认，不阻塞 UI
    }
  }

  // ── Getters ───────────────────────────────
  String get providerId => _providerId;
  String get apiKey => _apiKey;
  String get baseUrl => _baseUrl;
  String get model => _model;
  bool get useCustomProvider => _useCustomProvider;

  bool get feishuEnabled => _feishuEnabled;
  String get feishuAppId => _feishuAppId;
  String get feishuAppSecret => _feishuAppSecret;
  bool get wecomEnabled => _wecomEnabled;
  String get wecomBotId => _wecomBotId;
  String get wecomSecret => _wecomSecret;
  bool get dingtalkEnabled => _dingtalkEnabled;
  String get dingtalkClientId => _dingtalkClientId;
  String get dingtalkClientSecret => _dingtalkClientSecret;

  bool get skillWebSearch => _skillWebSearch;
  bool get skillCodeRun => _skillCodeRun;
  bool get skillMemory => _skillMemory;

  bool get autoStartGateway => _autoStartGateway;
  int get maxTokens => _maxTokens;

  /// 当前选中的供应商模板（自定义时返回 null）
  ProviderTemplate? get selectedTemplate {
    if (_useCustomProvider) return null;
    try {
      return kProviderTemplates.firstWhere((t) => t.id == _providerId);
    } catch (_) {
      return null;
    }
  }

  // ── Setters（带通知） ─────────────────────
  void selectProvider(String id) {
    final t = kProviderTemplates.where((e) => e.id == id).firstOrNull;
    if (t == null) return;
    _providerId = id;
    _useCustomProvider = false;
    _baseUrl = t.baseUrl;
    _model = t.defaultModel;
    notifyListeners();
  }

  void setCustomProvider() {
    _useCustomProvider = true;
    notifyListeners();
  }

  void setApiKey(String v) {
    _apiKey = v;
    notifyListeners();
  }

  void setBaseUrl(String v) {
    _baseUrl = v;
    notifyListeners();
  }

  void setModel(String v) {
    _model = v;
    notifyListeners();
  }

  void setFeishu({bool? enabled, String? appId, String? appSecret}) {
    if (enabled != null) _feishuEnabled = enabled;
    if (appId != null) _feishuAppId = appId;
    if (appSecret != null) _feishuAppSecret = appSecret;
    notifyListeners();
  }

  void setWecom({bool? enabled, String? botId, String? secret}) {
    if (enabled != null) _wecomEnabled = enabled;
    if (botId != null) _wecomBotId = botId;
    if (secret != null) _wecomSecret = secret;
    notifyListeners();
  }

  void setDingtalk({bool? enabled, String? clientId, String? clientSecret}) {
    if (enabled != null) _dingtalkEnabled = enabled;
    if (clientId != null) _dingtalkClientId = clientId;
    if (clientSecret != null) _dingtalkClientSecret = clientSecret;
    notifyListeners();
  }

  void setSkill({bool? webSearch, bool? codeRun, bool? memory}) {
    if (webSearch != null) _skillWebSearch = webSearch;
    if (codeRun != null) _skillCodeRun = codeRun;
    if (memory != null) _skillMemory = memory;
    notifyListeners();
  }

  void setSettings({bool? autoStart, int? maxTokens}) {
    if (autoStart != null) _autoStartGateway = autoStart;
    if (maxTokens != null) _maxTokens = maxTokens;
    notifyListeners();
  }

  static String _yamlQuote(String value) {
    // YAML 双引号字符串内需要转义反斜杠和双引号
    return '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
  }

  /// 生成 Hermes config.yaml 的 model 段（只这一段；写盘时增量合并，绝不整体覆盖，
  /// 否则会丢掉 BootstrapManager 初始化写入的 `gateway: mode: local` 段导致网关失效）
  String toConfigYaml() {
    final envKey = _useCustomProvider
        ? 'HERMES_API_KEY'
        : (selectedTemplate?.envKey ?? 'HERMES_API_KEY');
    final provider = _useCustomProvider
        ? 'custom'
        : (selectedTemplate?.hermesProvider ?? _providerId);
    return '''
model:
  provider: ${_yamlQuote(provider)}
  default: ${_yamlQuote(_model)}
  base_url: ${_yamlQuote(_baseUrl)}
  api_key: ${_yamlQuote('\${$envKey}')}
''';
  }

  /// 把当前 model 段替换到已有 config.yaml 中，保留 gateway 等其他段。
  /// 旧版用正则 `^model:\n(?:[ \t].*\n?)*` 匹配，遇到空行会截断，导致替换后
  /// 残留旧 model 字段或格式错误，是 config.yaml 解析失败的元凶之一。
  /// 这里改成按行解析：找到 model 块起止，整块替换。
  static String _replaceModelBlock(String oldYaml, String newModelBlock) {
    final lines = oldYaml.split('\n');
    final result = <String>[];
    int? modelStart;
    int modelEnd = lines.length; // 默认到末尾

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed == 'model:') {
        modelStart = i;
        continue;
      }
      if (modelStart != null && trimmed.isNotEmpty) {
        // model 块的子行必须比 model: 行缩进更多（至少一个空格）
        // 一旦遇到不缩进或同级/更高级别的键，说明 model 块结束
        if (!line.startsWith(' ') && !line.startsWith('\t')) {
          modelEnd = i;
          break;
        }
      }
    }

    if (modelStart != null) {
      // 保留 model 块之前的内容
      result.addAll(lines.sublist(0, modelStart));
      // 追加新 model 块
      result.add(newModelBlock.trimRight());
      // 保留 model 块之后的内容
      if (modelEnd < lines.length) {
        result.addAll(lines.sublist(modelEnd));
      }
    } else {
      // 原配置没有 model 段，追加到末尾
      result.addAll(lines);
      if (result.isNotEmpty && result.last.trim().isNotEmpty) {
        result.add('');
      }
      result.add(newModelBlock.trimRight());
    }

    return result.join('\n');
  }
  /// 收集当前受管键的键值（仅启用渠道写入；禁用/空值不在此列表中→保存时被移除）
  Map<String, String> managedEnvEntries() {
    final m = <String, String>{};
    final keyName = _useCustomProvider ? 'HERMES_API_KEY' : (selectedTemplate?.envKey ?? 'HERMES_API_KEY');
    if (_apiKey.isNotEmpty) m[keyName] = _apiKey;
    if (_feishuEnabled) {
      m['FEISHU_APP_ID'] = _feishuAppId;
      m['FEISHU_APP_SECRET'] = _feishuAppSecret;
    }
    if (_wecomEnabled) {
      m['WECOM_BOT_ID'] = _wecomBotId;
      m['WECOM_SECRET'] = _wecomSecret;
    }
    if (_dingtalkEnabled) {
      m['DINGTALK_CLIENT_ID'] = _dingtalkClientId;
      if (_dingtalkClientSecret.isNotEmpty) m['DINGTALK_CLIENT_SECRET'] = _dingtalkClientSecret;
    }
    return m;
  }

  /// 把受管键增量合并写入 ~/.hermes/.env（保留非受管键，如 ANDROID_BRIDGE_TOKEN）
  /// [extra] 可附加一次性键（如仅写渠道时不影响模型键）
  Future<void> saveEnv({Map<String, String>? extra}) async {
    final path = 'root/.hermes/.env';
    String existing = '';
    try {
      existing = await NativeBridge.readRootfsFile(path) ?? '';
    } catch (_) {
      existing = '';
    }
    final lines = existing.split('\n');
    final kept = <String>[];
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) {
        kept.add(line);
        continue;
      }
      if (t.startsWith('#')) {
        kept.add(line);
        continue;
      }
      final idx = t.indexOf('=');
      if (idx < 0) {
        kept.add(line);
        continue;
      }
      final k = t.substring(0, idx).trim();
      // 丢弃旧的受管键（稍后按当前状态重写）
      if (managedKeys.contains(k)) continue;
      kept.add(line);
    }
    // 当前受管键值
    final entries = managedEnvEntries();
    if (extra != null) entries.addAll(extra);
    final sb = StringBuffer();
    for (final l in kept) {
      sb.writeln(l);
    }
    // 去掉末尾多余空行
    var text = sb.toString().replaceAll(RegExp(r'\n+$'), '');
    if (text.isNotEmpty) text += '\n';
    for (final e in entries.entries) {
      text += '${e.key}=${e.value}\n';
    }
    await NativeBridge.writeRootfsFile(path, text);
  }

  /// 写配置：增量合并 config.yaml 的 model 段（保留 BootstrapManager 生成的 gateway 段）
  /// + 增量合并 .env（供「保存并重启网关」调用）。
  /// 关键：绝不能整体覆盖 config.yaml，否则会丢掉 `gateway: mode: local` 导致网关失效。
  Future<void> writeConfigFiles() async {
    final path = 'root/.hermes/config.yaml';
    String old = '';
    try {
      old = await NativeBridge.readRootfsFile(path) ?? '';
    } catch (_) {
      old = '';
    }
    final modelBlock = toConfigYaml();
    String newCfg;
    if (old.trim().isEmpty) {
      // 首次：补全 gateway 段（本地模式）+ model 段
      newCfg = 'gateway:\n  mode: local\n$modelBlock';
    } else {
      // 已有配置：只替换 model 段，保留 gateway 等其他段
      newCfg = _replaceModelBlock(old, modelBlock);
    }
    await NativeBridge.writeRootfsFile(path, newCfg);
    await saveEnv();
  }
}
