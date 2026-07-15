import 'package:flutter/material.dart';
import '../models/provider_template.dart';
import '../services/native_bridge.dart';

/// Hermes 真实渠道变量名（官方文档 hermesagent.org.cn，无 HERMES_ 前缀，写 ~/.hermes/.env）
/// 飞书:    FEISHU_APP_ID / FEISHU_APP_SECRET
/// 企微:    WECOM_BOT_ID / WECOM_SECRET
/// 钉钉:    DINGTALK_CLIENT_ID / DINGTALK_CLIENT_SECRET
/// 微信:    WEIXIN_ACCOUNT_ID / WEIXIN_TOKEN
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

  // ── 渠道配置（国内四件套：飞书/企微/钉钉/微信） ──
  bool _feishuEnabled = false;
  String _feishuAppId = '';
  String _feishuAppSecret = '';

  bool _wecomEnabled = false;
  String _wecomBotId = '';
  String _wecomSecret = '';

  bool _dingtalkEnabled = false;
  String _dingtalkClientId = '';
  String _dingtalkClientSecret = '';

  bool _weixinEnabled = false;
  String _weixinAccountId = '';
  String _weixinToken = '';

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
    'FEISHU_APP_ID',
    'FEISHU_APP_SECRET',
    'WECOM_BOT_ID',
    'WECOM_SECRET',
    'DINGTALK_CLIENT_ID',
    'DINGTALK_CLIENT_SECRET',
    'WEIXIN_ACCOUNT_ID',
    'WEIXIN_TOKEN',
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
      _weixinEnabled = map.containsKey('WEIXIN_ACCOUNT_ID') &&
          (map['WEIXIN_ACCOUNT_ID']?.isNotEmpty ?? false);
      _weixinAccountId = map['WEIXIN_ACCOUNT_ID'] ?? '';
      _weixinToken = map['WEIXIN_TOKEN'] ?? '';
      if (map.containsKey('HERMES_API_KEY')) _apiKey = map['HERMES_API_KEY'] ?? '';
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
  bool get weixinEnabled => _weixinEnabled;
  String get weixinAccountId => _weixinAccountId;
  String get weixinToken => _weixinToken;

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

  void setWeixin({bool? enabled, String? accountId, String? token}) {
    if (enabled != null) _weixinEnabled = enabled;
    if (accountId != null) _weixinAccountId = accountId;
    if (token != null) _weixinToken = token;
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

  /// 生成 Hermes config.yaml 的 model 段（只这一段；写盘时增量合并，绝不整体覆盖，
  /// 否则会丢掉 BootstrapManager 初始化写入的 `gateway: mode: local` 段导致网关失效）
  String toConfigYaml() => '''
model:
  provider: ${_useCustomProvider ? 'custom' : _providerId}
  default: $_model
  base_url: $_baseUrl
  api_key: \${HERMES_API_KEY}
''';

  /// 收集当前受管键的键值（仅启用渠道写入；禁用/空值不在此列表中→保存时被移除）
  Map<String, String> managedEnvEntries() {
    final m = <String, String>{};
    if (_apiKey.isNotEmpty) m['HERMES_API_KEY'] = _apiKey;
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
    if (_weixinEnabled) {
      m['WEIXIN_ACCOUNT_ID'] = _weixinAccountId;
      m['WEIXIN_TOKEN'] = _weixinToken;
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
      final modelPattern = RegExp(r'^model:\n(?:[ \t].*\n?)*', multiLine: true);
      if (old.contains(modelPattern)) {
        newCfg = old.replaceFirst(modelPattern, modelBlock);
      } else {
        // 原配置没有 model 段，追加到末尾
        newCfg = old.endsWith('\n') ? '$old$modelBlock' : '$old\n$modelBlock';
      }
    }
    await NativeBridge.writeRootfsFile(path, newCfg);
    await saveEnv();
  }
}
