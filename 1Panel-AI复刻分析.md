# 复刻 1Panel AI 面板 — 可行性分析

> 生成：2026-07-15 21:00｜臣哥要求研究 `1Panel-dev/1PanelAI` 能否复刻

## 1. 仓库真相（先纠错）

- **`1Panel-dev/1PanelAI` 这个仓库不存在（GitHub 404）**。
- 1Panel 的 AI 能力不是独立仓库，而是两部分：
  1. **开源版 `1Panel-dev/1Panel`**（GPL-3.0，Go 后端 + Vue3 前端，最新 v2.2.2）：内置 **AI 模块**，代码在 `agent/` 目录 + `core/` 后端逻辑 + `frontend/` Vue 界面。
  2. **企业版 AI 门户**（闭源，但官网公开了功能清单）：面向企业的 AI 自助入口（API Key 自助、模型广场、技能市场、MCP 市场、后台运营）。
- **待看图里 9 张截图的对应**：
  - 大图(538K) 模型管理表格、中图(113K) API Key 管理、深色图(70K) OpenClaw/Codex 供应商列表 → **1Panel AI 面板**
  - 小图 e3c/bfa/c87/f3f/f61（频道/模型/设置/技能）→ **Hermes-Agent 自身的 Web 配置界面**（不是 1Panel）

**结论**：臣哥想复刻的"1PanelAI"，实际就是 **1Panel 的 AI 管理面板（模型/供应商/API Key/智能体/技能市场）**。这正是我们 sutaagent 新版要做的事。

## 2. 1Panel AI 板块功能全貌

### 2.1 开源版（1Panel-dev/1Panel）
- 技术栈：Go 后端（`core/`）+ Vue3 + TypeScript 前端（`frontend/`）；AI 逻辑集中在 `agent/` 目录。
- 能力：一键部署 **Ollama 本地大模型**、启动 **OpenClaw 个人智能体**、**GPU 监控**、MCP 服务、Skills。OSS 版限 1 个 OpenClaw agent，Pro 版不限。

### 2.2 企业版 AI 门户（闭源，功能清单公开）
- **用户自助**：API Key 自助申请/查看/重置/删除 + 用量统计。
- **市场分发**：模型广场、技能市场、MCP 市场（按分类浏览、搜索、安装）。
- **后台运营**：技能提交与审核发布、用户管理、OAuth 登录配置、对接企业微信/钉钉/飞书、1Panel 网关配置。

## 3. 我们能复刻哪些（功能层，用 Flutter + Hermes 重写）

| 1Panel 功能 | 能否复刻 | 我们的现状 / 做法 |
|---|---|---|
| 模型 / 供应商管理 | ✅ | `config_provider.dart` 已有写盘能力，修 `model.default` schema + 增强 UI 即可 |
| API Key 管理 | ✅ | 复用 config_provider + 已做的"连通性验证"按钮 |
| 智能体创建（Hermes / OpenClaw） | ✅ | 已有 `GatewayService` / `ProcessManager` 进程管理，扩展成列表+创建 |
| 技能市场 | ✅ | 后端 `hermes skills search/install` 已可用，包成卡片 UI + 一键装 |
| 模型广场 | ✅ | 静态/动态模型列表页 |
| 对话 / 聊天 GUI | ✅ | 终端已能进 Hermes 对话，套 GUI 聊天界面 |
| 渠道对接（微信扫码等） | ⚠️ | 依赖 Hermes 渠道能力；待看图 e3c 已有微信"扫码对接"参照 |
| Docker / GPU / 服务器运维 | ❌ | 1Panel 是 Linux 服务器面板，我们是 Android APP，非场景 |
| 企业版多租户 / OAuth 治理 | ❌ | 个人/小团队场景暂不需要 |

## 4. 合规提醒（臣哥做赚钱项目，必须看）

- 1Panel 是 **GPL-3.0**。如果**直接拷贝它的 Vue 前端代码**，会被认定为衍生作品，要求我们开源自己的产品——对闭源赚钱不利。
- **我们用 Flutter 重写（不同语言 + 不同框架）= 干净实现，不触发 GPL 传染性**。我们本来就是独立产品（Hermes 遥控器），功能对标、自己重写，没有合规问题。
- **红线**：借鉴产品形态 + 自己重写实现，**绝不拷贝 1Panel 的代码 / 抄它的 API 字段命名**。

## 5. 复刻路线图（节奏放慢、逐步验证）

- **P0（基础，其他功能都依赖它）**：模型/供应商管理 + API Key 管理面板（对标大图/中图/小图 f3f）。我们已有约 80% 能力，先修 `model.default` schema 起步。
- **P1**：技能市场（卡片化 `hermes skills`）+ 智能体创建列表（Hermes/OpenClaw）。
- **P2**：渠道对接（微信扫码）+ 模型广场 + GUI 聊天界面。

## 6. 建议

1. **方向钉死**：sutaagent 新版 = 复刻 1Panel AI 管理面板（移动端形态 + Hermes 后端），这是最对标的开源参照，不用自己拍脑袋设计。
2. **最小切片先做 P0**：自测后给臣哥看真机效果，再推进 P1/P2。
3. **不碰服务器运维部分**（Docker/GPU），那不是我们的场景，1Panel 主业也不是我们的目标。
4. **合规**：全程 Flutter 重写，不拷代码。
