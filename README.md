# Hermes 手机端（安卓 Termux · 中文版）

> 手机本地运行 Hermes Agent 的调度层，**只有大模型推理走云端 API**。不是云端服务器、不在手机上跑模型。

本仓库是**原创实现**（参考了 `amirghm/hermes-agent-mobile` 的"手机本地跑 Agent"思路，但代码完全自己写、更轻）。
核心理念：**Agent 本体完整驻留手机本地，仅 LLM 推理请求发往云端 OpenAI 兼容接口**。

---

## 一、它到底是什么

| 部分 | 跑在哪 | 说明 |
|------|--------|------|
| **Hermes 调度层** | 手机本地（Termux） | 思考链、工具调用决策、记忆库、上下文管理、任务队列、多轮对话闭环 |
| **本地工具** | 手机本地 | 文件读写、本地搜索、命令执行、定时任务（cron）、Web 搜索 |
| **大模型推理** | 云端 API | 仅把 prompt 发往 OpenRouter / 智谱 / DeepSeek / Kimi 等，收到回答后本地继续调度 |
| **配置 / 密钥 / 记忆** | 手机本地 | 全部存在 `~/.hermes/`，不经过任何第三方服务器 |

### 和两种"伪本地"方案的区别

- ❌ **纯远程控制 APP**：手机只发指令、云端跑 Hermes（这不是本方案）
- ❌ **手机本地跑大模型**：Ollama / 量化模型本地推理（你明确不需要，太吃资源）
- ✅ **本方案**：Hermes 本体完整在手机本地，仅 LLM 推理走云端 API

---

## 二、特性

- 🏠 **随身可用**：Assistant 在你口袋里，不用开电脑、不用连服务器
- 💬 **Telegram 网关**（可选）：用 Telegram 给 Agent 发消息/语音/文件，像带了个团队
- 🔋 **可后台保活**：配合[后台保活指南](docs/后台保活指南.md)，锁屏也能 24/7 跑
- 💰 **成本极低**：默认走 OpenRouter 免费的 `xiaomi/mimo-v2.5`；也支持国内智谱/DeepSeek/Kimi
- 🔒 **数据留本地**：对话与记忆存在手机，云端只传 prompt
- 🪶 **极简**：原生 Termux 安装，不需要 proot 装 Debian、不需要 Firefox，存储占用小

---

## 三、前置要求

| 项目 | 说明 |
|------|------|
| 手机系统 | 安卓（iOS 暂不做，沙盒限制无法本地驻留进程） |
| 应用 | [Termux](https://f-droid.org/zh_Hans/packages/com.termux/)（F-Droid 或 GitHub 版，Google Play 版较旧） |
| 存储 | 约 2–4 GB 空闲（含 Python 环境与依赖） |
| 网络 | 能访问 GitHub / PyPI / 你选的模型 API |
| 密钥 | 任一云端 LLM 的 API Key（见下方"获取 Key"） |

首次打开 Termux 建议先执行：

```bash
pkg update && pkg upgrade -y
termux-setup-storage   # 授予存储权限（可选，方便读写手机文件）
```

---

## 四、一键安装

在 Termux 里执行**一条命令**（脚本会引导你选模型服务商、填 Key）：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/const1981/hermes-agent-mobile-zh/main/scripts/install-termux.sh)
```

脚本会依次：
1. 让你选大模型提供商（OpenRouter / 智谱 / DeepSeek / Kimi / 自定义）
2. 收集 API Key（输入不回显）
3. 设置清华 pip 镜像（加速 ARM 上的依赖安装）
4. 调用上游官方安装器装好 `hermes-agent`（Termux 精简版，已自动排除本地语音依赖）
5. 写入中文配置到 `~/.hermes/config.yaml` 与 `.env`
6. 可选启动 Telegram 网关
7. 直接进入 Hermes 对话

> 安装器调用的是上游官方脚本 `https://hermes-agent.nousresearch.com/install.sh`（仅用于装 Agent 本体，本仓库不打包其代码）。

---

## 五、获取 API Key

| 提供商 | 免费模型 | 申请地址 |
|--------|----------|----------|
| **OpenRouter** | `xiaomi/mimo-v2.5`（免费） | https://openrouter.ai/keys |
| **智谱 GLM** | `glm-4-flash`（有免费额度） | https://open.bigmodel.cn/usercenter/apikeys |
| **DeepSeek** | `deepseek-chat` | https://platform.deepseek.com/api_keys |
| **Kimi（月之暗面）** | `moonshot-v1-8k` | https://platform.moonshot.cn/console/api-keys |

> 小米 MiMo 用户：直接用 OpenRouter 上的 `xiaomi/mimo-v2.5`（免费）即可，无需单独接入。

---

## 六、常用命令

```bash
hermes            # 启动本地 Hermes 对话
hermes setup      # 交互式配置（改模型 / 密钥 / 网关）
hermes gateway    # 启动 Telegram 等消息网关
```

---

## 七、后台保活（重要）

安卓会杀后台进程，锁屏后 Agent 可能停。按 [docs/后台保活指南.md](docs/后台保活指南.md) 设置：
电池优化 → 不优化、开启 Termux 唤醒锁、关闭 Phantom Process Killer（Android 12+ 需 ADB）。

---

## 八、目录结构

```
hermes-agent-mobile-zh/
├── scripts/
│   └── install-termux.sh      # 一键安装脚本（原创，中文交互）
├── docs/
│   └── 后台保活指南.md         # 安卓 12+ 后台保活（含国产机路径）
├── config/
│   ├── config.yaml.example     # 各 provider 配置样例（中文注释）
│   └── .env.example            # 密钥变量样例
└── README.md
```

---

## 九、常见问题

**Q：安装很慢 / pip 报错？**
A：国内网络建议保持清华 pip 镜像（脚本已默认设置）。若镜像陈旧，可在 Termux 执行 `termux-change-repo` 切换源后重跑安装。

**Q：想换模型或换 Key？**
A：直接 `hermes setup` 走官方向导，或编辑 `~/.hermes/config.yaml` 与 `~/.hermes/.env`。

**Q：语音输入（STT）/ 浏览器自动化能不能用？**
A：原生 Termux 版默认不含本地语音依赖（ARM 上 `ctranslate2` 无官方 wheel）。聊天、Telegram、cron、技能、文件操作、Web 搜索均可用；浏览器自动化需在 proot 环境中额外配置，本极简版暂未包含。

**Q：iOS 能用吗？**
A：本仓库聚焦安卓。iOS 因沙盒限制无法本地驻留 Hermes 进程，暂不提供支持。

---

## 许可证

MIT。本仓库为原创脚本与文档；底层 `hermes-agent` 引擎版权归其上游作者所有。
