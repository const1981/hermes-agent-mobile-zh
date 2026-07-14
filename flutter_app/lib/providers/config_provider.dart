import 'package:flutter/material.dart';
import '../models/provider_template.dart';

/// 配置状态（对标 1Panel 配置页：频道/模型/技能/设置）
class ConfigProvider extends ChangeNotifier {
  ConfigProvider() {
    _loadFromPrefs();
  }

  // ── 模型配置 ──────────────────────────────
  String _providerId = 'deepseek';
  String _apiKey = '';
  String _baseUrl = kProviderTemplates.first.baseUrl;
  String _model = kProviderTemplates.first.defaultModel;
  bool _useCustomProvider = false; // 自定义供应商（手动填全部）

  // ── 频道配置（飞书/微信等） ──────────────
  bool _feishuEnabled = false;
  String _feishuAppId = '';
  String _feishuAppSecret = '';
  bool _wechatEnabled = false;
  String _wechatToken = '';
  String _wechatEncodingAesKey = '';

  // ── 技能开关 ──────────────────────────────
  bool _skillWebSearch = false;
  bool _skillCodeRun = true;
  bool _skillMemory = true;

  // ── 设置 ──────────────────────────────────
  bool _autoStartGateway = true;
  int _maxTokens = 4096;

  // ── 持久化 ────────────────────────────────
  // 简化：用 SharedPreferences 存 UI 侧配置；Hermes 真实配置写 proot 内 config.yaml
  void _loadFromPrefs() {
    // 实际项目里从 SharedPreferences 读；此处保留默认 + 后续接 NativeBridge
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
  bool get wechatEnabled => _wechatEnabled;
  String get wechatToken => _wechatToken;
  String get wechatEncodingAesKey => _wechatEncodingAesKey;

  bool get skillWebSearch => _skillWebSearch;
  bool get skillCodeRun => _skillCodeRun;
  bool get skillMemory => _skillMemory;

  bool get autoStartGateway => _autoStartGateway;
  int get maxTokens => _maxTokens;

  // ── 当前选中的供应商模板 ──────────────────
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

  void setWechat({bool? enabled, String? token, String? aesKey}) {
    if (enabled != null) _wechatEnabled = enabled;
    if (token != null) _wechatToken = token;
    if (aesKey != null) _wechatEncodingAesKey = aesKey;
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

  /// 生成 Hermes config.yaml 的 model 段内容（供写盘用）
  String toModelYaml() => '''
model:
  provider: ${_useCustomProvider ? 'custom' : _providerId}
  model: $_model
  base_url: $_baseUrl
  api_key: \${HERMES_API_KEY}
''';

  /// 生成 .env 的密钥（供写盘用）
  String toEnv() => 'HERMES_API_KEY=$_apiKey\n';
}
