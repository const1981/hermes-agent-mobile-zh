/// 预设 LLM 供应商模板 —— 用户选一个只需填 API Key 即可。
/// 对标 1Panel 模型管理页的常用供应商列表。
/// 数据来源：各平台官方 API 文档（2026-07）。
class ProviderTemplate {
  const ProviderTemplate({
    required this.id,
    required this.name,
    required this.icon,
    required this.baseUrl,
    required this.defaultModel,
    required this.models,
    this.description = '',
    this.keyLabel = 'API Key',
    this.keyHint = 'sk-...',
    this.docUrl,
  });

  /// 唯一标识（存盘用）
  final String id;

  /// 显示名称（中文）
  final String name;

  /// 图标 emoji
  final String icon;

  /// OpenAI 兼容 Base URL
  final String baseUrl;

  /// 默认推荐模型
  final String defaultModel;

  /// 该平台支持的常用模型列表（供用户切换）
  final List<String> models;

  /// 简短描述
  final String description;

  /// 密钥字段标签
  final String keyLabel;

  /// 密钥输入提示
  final String keyHint;

  /// 官方文档/控制台链接（帮助用户获取 Key）
  final String? docUrl;
}

/// 全部预设供应商（按国内常用度排序）
const List<ProviderTemplate> kProviderTemplates = [
  // ── DeepSeek ──────────────────────────────
  ProviderTemplate(
    id: 'deepseek',
    name: 'DeepSeek',
    icon: '🔷',
    baseUrl: 'https://api.deepseek.com',
    defaultModel: 'deepseek-reasoner',
    models: [
      'deepseek-reasoner',
      'deepseek-chat',
      'deepseek-coder',
    ],
    description: '深度求索，国产顶级推理模型',
    docUrl: 'https://platform.deepseek.com/api_keys',
  ),

  // ── 智谱 GLM (ZhipuAI) ────────────────────
  ProviderTemplate(
    id: 'zhipu',
    name: '智谱 GLM',
    icon: '🧠',
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    defaultModel: 'glm-5',
    models: [
      'glm-5',
      'glm-5-flash',
      'glm-4-plus',
      'glm-4-flash',
      'glm-4-long',
      'codegeex-4',
    ],
    description: '智谱 AI，GLM-5 系列大模型',
    keyLabel: 'API Key',
    docUrl: 'https://open.bigmodel.cn/usercenter/apikeys',
  ),

  // ── Kimi (Moonshot) ───────────────────────
  ProviderTemplate(
    id: 'kimi',
    name: 'Kimi',
    icon: '🌙',
    baseUrl: 'https://api.moonshot.cn/v1',
    defaultModel: 'kimi-k2-0711-preview',
    models: [
      'kimi-k2-0711-preview',
      'moonshot-v1-128k',
      'moonshot-v1-32k',
      'moonshot-v1-auto',
    ],
    description: '月之暗面 Kimi，超长上下文对话',
    docUrl: 'https://platform.moonshot.cn/console/api-keys',
  ),

  // ── 通义千问 Qwen (阿里) ─────────────────
  ProviderTemplate(
    id: 'qwen',
    name: '通义千问',
    icon: '💬',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    defaultModel: 'qwen3-coder-plus',
    models: [
      'qwen3-coder-plus',
      'qwen3-plus',
      'qwen3-max',
      'qwen3-turbo',
      'qwen2.5-72b-instruct',
      'qwq-32b',
    ],
    description: '阿里云通义千问，Qwen3 系列',
    keyLabel: 'DashScope API Key',
    docUrl: 'https://dashscope.console.aliyun.com/apiKey',
  ),

  // ── 小米 MiMo（普通版） ───────────────────
  ProviderTemplate(
    id: 'mimo',
    name: '小米 MiMo',
    icon: '📱',
    baseUrl: 'https://api.xiaomimimo.com/v1',
    defaultModel: 'mimo-v2.5',
    models: [
      'mimo-v2.5',
      'mimo-v2.5-pro',
      'mimo-v2.5-mini',
    ],
    description: '小米多模态 AI（普通版）',
    docUrl: '',
  ),

  // ── 小米 MiMo Plan（Pro 计划版） ─────────
  ProviderTemplate(
    id: 'mimo-plan',
    name: '小米 MiMo Pro',
    icon: '📱',
    baseUrl: 'https://api.xiaomimimo.com/v1',
    defaultModel: 'mimo-v2.5-pro',
    models: [
      'mimo-v2.5-pro',
      'mimo-v2.5',
    ],
    description: '小米多模态 AI Pro 计划版（更高配额）',
    keyLabel: 'Pro API Key',
    docUrl: '',
  ),

  // ── 百度千帆 (Baidu Qianfan) ─────────────
  ProviderTemplate(
    id: 'qianfan',
    name: '百度千帆',
    icon: '🐾',
    baseUrl: 'https://qianfan.baidubce.com/v2',
    defaultModel: 'ernie-code-4k-turbo',
    models: [
      'ernie-code-4k-turbo',
      'ernie-speed-128k',
      'ernie-4.0-8k',
      'ernie-4.0-turbo-8k',
      'ernie-lite-8k',
    ],
    description: '百度智能云千帆平台',
    keyLabel: 'API Key / Access Token',
    keyHint: 'ALT-... 或 aak-...',
    docUrl:
        'https://console.bce.baidu.com/qianfan/ais/console/applicationConsole/application',
  ),

  // ── 火山引擎 Ark (字节跳动) ──────────────
  ProviderTemplate(
    id: 'ark',
    name: '火山引擎',
    icon: '🌋',
    baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
    defaultModel: 'ark-code-latest',
    models: [
      'ark-code-latest',
      'doubao-1-5-pro-256k',
      'doubao-1-5-lite-32k',
      'doubao-seed-240628',
    ],
    description: '字节跳动火山引擎，豆包系列',
    keyLabel: 'API Key',
    docUrl:
        'https://console.volcengine.com/ark/region:ark+cn-beijing/apiKeyManagement',
  ),

  // ── StepFun (阶跃星辰) ──────────────────
  ProviderTemplate(
    id: 'stepfun',
    name: 'StepFun',
    icon: '🪜',
    baseUrl: 'https://api.stepfun.com/v1',
    defaultModel: 'step-3.5-flash-l2603',
    models: [
      'step-3.5-flash-l2603',
      'step-3.5-ultra',
      'step-2-mini',
    ],
    description: '阶跃星辰 Step 系列',
    docUrl: 'https://platform.stepfun.com/#/quickstart',
  ),

  // ── MiniMax ─────────────────────────────
  ProviderTemplate(
    id: 'minimax',
    name: 'MiniMax',
    icon: '🎯',
    baseUrl: 'https://api.minimax.io/v1',
    defaultModel: 'MiniMax-M2.7',
    models: [
      'MiniMax-M2.7',
      'MiniMax-Text-01',
      'abab6.5s-chat',
    ],
    description: 'MiniMax 对话模型',
    docUrl: 'https://platform.minimaxi.com/user-center/basic-information/interface-key',
  ),

  // ── 火山方舟 / ModelScope ───────────────
  ProviderTemplate(
    id: 'modelscope',
    name: 'ModelScope',
    icon: '🏠',
    baseUrl: 'https://api.modelscope.cn/v1',
    defaultModel: 'ZhipuAI/GLM-5.1',
    models: [
      'ZhipuAI/GLM-5.1',
      'Qwen/Qwen3-235B-A22B',
      'deepseek-ai/DeepSeek-V3',
    ],
    description: '魔搭社区模型服务',
    docUrl: 'https://modelscope.cn/my/myaccesstoken',
  ),

  // ── LongCat (美团) ───────────────────────
  ProviderTemplate(
    id: 'longcat',
    name: 'LongCat',
    icon: '🐱',
    baseUrl: 'https://api.longcat.ai/v1',
    defaultModel: 'LongCat-Flash-Chat',
    models: [
      'LongCat-Flash-Chat',
      'LongCat-Pro',
    ],
    description: '美团 LongCat 对话模型',
    docUrl: '',
  ),
];
