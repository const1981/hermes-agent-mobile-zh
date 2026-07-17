# Hermes 手机端（安卓 · 中文版）

> **当前状态：生产稳定 — 维护态**

手机本地运行 Hermes Agent 的调度层，**只有大模型推理走云端 API**。不是云端服务器、不在手机上跑模型。

**最新版本：v0.3.45+77**（2026-07-17 发布）  
**许可证：[AGPL-3.0](LICENSE)**（2026-07-16 由 MIT 迁移至 AGPLv3）

---

## 一、项目定位

| 部分 | 跑在哪 | 说明 |
|------|--------|------|
| **Hermes 调度层** | 手机本地 | 思考链、工具调用决策、记忆库、上下文管理、任务队列、多轮对话闭环 |
| **本地工具** | 手机本地 | 文件读写、本地搜索、命令执行、定时任务（cron）、Web 搜索 |
| **大模型推理** | 云端 API | 仅把 prompt 发往 OpenRouter / 智谱 / DeepSeek / Kimi / 小米 MiMo / SiliconFlow 等，收到回答后本地继续调度 |
| **配置 / 密钥 / 记忆** | 手机本地 | 全部存在 `~/.hermes/`，不经过任何第三方服务器 |

**核心差异：** 市面上其他方案要么是"纯远程控制 APP"（手机只发指令、云端跑 Hermes），要么是"手机本地跑大模型"（Ollama / 量化模型本地推理，太吃资源）。本方案 **Hermes 本体完整在手机本地，仅 LLM 推理走云端 API**，兼得随身可用与性能。

---

## 二、特性一览

| 特性 | 说明 |
|------|------|
| 🏠 **随身可用** | Assistant 在你口袋里，不用开电脑、不用连服务器 |
| 💬 **消息渠道网关** | 飞书 / 企业微信 / 钉钉 三种渠道填 Key 即配，Telegram 可额外配置 |
| 🔋 **后台保活** | 3 个前台 Service（网关/终端/安装）+ 配合保活指南，锁屏也能 24/7 跑 |
| 💰 **成本可控** | 支持 OpenRouter / 智谱 / DeepSeek / Kimi / 小米 MiMo / SiliconFlow 等，国内厂商有免费额度 |
| 🔒 **数据留本地** | 对话与记忆存在手机 `filesDir/rootfs/debian`，云端只传 prompt |
| 🌐 **中英文切换** | 默认中文，设置页可切「跟随系统 / 简体中文 / English」|
| 🎨 **一键安装** | APK 内置 proot + Debian 运行环境，点图标即用，5 步向导全程界面点按 |
| ⏱ **断点续传** | rootfs / Python / Hermes 已存在则跳过，失败可从断点续传 |
| 🚀 **应用内更新** | 设置页「检查更新」一键拉取新版 APK（七牛云 `m.ebmma.com` 国内加速 + GitHub 兜底），不用再去网页手动下 |
| 💬 **对话页自动启动网关** | 进「对话」页自动拉起本地网关（18789），无需手动去仪表盘点启动 |
| 🚀 **终端常驻** | 单例 `TerminalSessionManager`，返回再进秒回对话，不冷启动 |
| 📋 **日志筛选** | 今天 / 近 1 小时 / 近 24 小时 / 全部时间范围 |
| 💾 **系统镜像** | Ghost 式打包导出 `rootfs/debian`，可本地或局域网下载 |
| 🐧 **Debian 根系统** | v0.3.42 起由 Ubuntu 24.04 换为 **Debian 12 (bookworm)**（proot-distro 官方 rootfs），更精简、apt 走清华镜像 |

---

## 三、App 架构

```
┌─────────────────────────────────────────────────────────┐
│  Flutter App (Dart UI)                                 │
│  Splash / 对话 / 仪表盘 / 配置 / 设置 (四Tab) / Terminal  │
│  Settings / SystemImage / Logs                          │
├─────────────────────────────────────────────────────────┤
│  Providers (状态管理)                                    │
│  Config / Gateway / Locale / Setup                     │
├─────────────────────────────────────────────────────────┤
│  Services (业务层)                                       │
│  Bootstrap / Gateway / Terminal / TerminalSessionMgr    │
│  UpdateService (应用内更新)                              │
├─────────────────────────────────────────────────────────┤
│  NativeBridge (MethodChannel) ~40+ methods              │
├─────────────────────────────────────────────────────────┤
│  Android Kotlin Layer                                   │
│  MainActivity / BootstrapManager / ProcessManager       │
│  GatewayService(前台) / ArchUtils                       │
├─────────────────────────────────────────────────────────┤
│  proot + Debian 12 bookworm (ARM64 运行环境)             │
├─────────────────────────────────────────────────────────┤
│  Hermes Agent 引擎 (Python, 手机本地调度)                 │
│  功能：思考链 / 工具调用 / 记忆库 / 多轮对话 / 任务队列     │
└─────────────────────────────────────────────────────────┘
```

核心数据流：安装向导 → proot 内装 Hermes → 填 Key 配模型 → 启网关 (18789) → 对话页 / 终端对话

---

## 四、前置要求

| 项目 | 说明 |
|------|------|
| 手机系统 | 安卓 8+（仅支持 ARM64 / armeabi-v7a，不支持 x86/x86_64 模拟器） |
| 存储 | 装 APK 约 40MB；首次运行需约 500MB~1GB（rootfs + pip 依赖） |
| 网络 | 能访问七牛云 `m.ebmma.com`（下载 Debian rootfs / 更新 APK，国内流量）/ PyPI / 模型 API |
| 密钥 | 任一云端 LLM 的 API Key |

---

## 五、安装使用

### 方式一：APK 一键安装（推荐）

1. 从 [GitHub Releases](https://github.com/const1981/hermes-agent-mobile-zh/releases) 下载最新 APK，或用 App 内「设置 → 检查更新」一键升级（七牛云 `m.ebmma.com` 国内加速）
2. 打开 App → **Begin Setup** → App 自动下载 Debian + 安装 Hermes（约 5–15 分钟，国内走清华镜像）
3. **无需手动启动网关**：应用启动即自动起网关（18789），进「对话」页也会自动拉起
4. 点「配置」→ 选服务商 + 填 API Key → 点「保存配置」（只写盘，不自动启停网关）
5. 进「对话」页或仪表盘终端，开始与 Hermes 对话

> ⚠️ **从 v0.3.37 及更早版本升级到 Debian 版（v0.3.42+）时**：旧 Ubuntu 环境不会自动变成 Debian，需进「设置 → 重新初始化」重新下载解压 Debian 环境。

### 方式二：Termux 脚本（备选/排障）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/const1981/hermes-agent-mobile-zh/main/scripts/install-termux.sh)
```

---

## 六、版本轨迹（v0.3.19 → v0.3.45）

| 版本 | 日期 | 关键更新 |
|------|------|----------|
| **v0.3.45** | 2026-07-17 | **P0 修复 Debian rootfs 解压后目录嵌套**：proot-distro 的 Debian tar 包内带顶层目录 `debian-bookworm-aarch64/`，v0.3.44 没剥掉导致 `bash not found`；新增自动检测并剥离顶层 wrapper 目录，rootfs 正确落到 `filesDir/rootfs/debian/` |
| **v0.3.44** | 2026-07-17 | **rootfs 镜像到七牛 + 中央清单文件**：Debian rootfs 三架构包镜像到七牛 `const/hermesmb`（国内流量，告别 GitHub 慢源）；新增七牛 `sources.json` 中央清单，App 启动时先拉清单解析 rootfs/更新源地址，**换源/换桶/换版本标签无需重发 App**；更新检查加 CDN 缓存破除 |
| **v0.3.43** | 2026-07-17 | **修复 Debian rootfs 解压失败**：修正 .tar.xz 流式解压逻辑，海外 GitHub 源直拉；发 Release |
| **v0.3.42** | 2026-07-17 | **根系统 Ubuntu → Debian 12 (bookworm)**（proot-distro 官方 rootfs，更精简、apt 走清华镜像）；全仓 `rootfs/ubuntu`→`rootfs/debian` |
| **v0.3.41** | 2026-07-17 | **对话页自动启动网关**：进「对话」页自动拉起网关，不再卡"要启动网关"；`autoStartGateway` 默认开启 |
| **v0.3.40** | 2026-07-17 | **应用内更新接通七牛云**：更新源落地 `const` 桶 `hermesmb/` 目录（`m.ebmma.com` 永久域名，HTTP 明文）；上传脚本 `tools/scripts/upload_apk_qiniu.py` |
| **v0.3.39** | 2026-07-17 | **应用内更新框架**：FileProvider + 系统安装器 + `UpdateService` + 设置页「检查更新」（七牛优先、GitHub 兜底） |
| v0.3.38 | 2026-07-17 | **P0 修复网关 0 秒崩溃**：去掉 `/bin/bash -c` 中间层，改由 venv python 直接 exec launch 脚本（规避 proot 下 bash ENOSYS） |
| v0.3.37 | 2026-07-17 | 网关只手动启停，崩溃后不再自动重启（去 maxRestarts 循环） |
| v0.3.36 | 2026-07-17 | **收敛网关开关**：只保留仪表盘「启动/停止网关」，删配置页「重启网关」与独立网关页 |
| v0.3.35 | 2026-07-17 | 网关启动入口收敛到仪表盘唯一主入口；配置页「保存配置」只写盘 |
| v0.3.34 | 2026-07-16 | **根治网关冷启卡死**：删 `hermes --version` proot 软自检；`runInProotSync` 默认超时 900s→60s；「验证连通性」改 Dart 直连 |
| v0.3.33 | 2026-07-16 | **底部 4 Tab 布局重构**（对话/仪表盘/配置/设置）；终端入口归位仪表盘、日志入口归位设置 |
| v0.3.32 | 2026-07-16 | 修复 proot 环境下 `/dev/null` 与 pipe 不支持导致启动失败（清理命令改 Python 脚本） |
| v0.3.31 | 2026-07-16 | **CI 密钥扫描门禁**（构建后反编译扫 smali 硬编码实值） |
| v0.3.30 | 2026-07-16 | 根治自残启动（pkill 把自己 shell 也杀）→ pgrep 列 PID 排除自身 |
| v0.3.29 | 2026-07-16 | ⚠️翻车：`pkill -f gateway` 自杀（exit 137），已下架 `.BROKEN-selfkill.apk` |
| v0.3.28 | 2026-07-16 | 统一国内 DNS（119.29.11.29 / 223.5.5.5） |
| v0.3.27 | 2026-07-16 | 微信风「对话」页上线（SSE 流式） |
| v0.3.26 | 2026-07-16 | 修终端会话坏死 + 模型配置被覆盖 + uname 架构硬编码 |
| v0.3.25 | 2026-07-15 | 移除微信渠道（扫码登录需另做），保留飞书/企微/钉钉 |
| v0.3.24 | 2026-07-15 | **根治 config.yaml 解析失败**（YAML 引号+块替换修复） |
| v0.3.23 | 2026-07-15 | 修复模拟器卡在第二步（proot 前置检测 20s 短超时报错） |
| v0.3.22 | 2026-07-15 | **终端进程常驻** / 日志时间筛选 / MiMo key 映射修复 |
| v0.3.21 | 2026-07-15 | 修复 MiMo key 映射（provider `mimo`→`xiaomi`） |
| v0.3.20 | 2026-07-15 | **P0 修复 config 写盘 schema** / 移除整文件夹备份 / 终端美化 / 安装引导横幅 |
| v0.3.19 | 2026-07-15 | **根治网关自关 & hermes not found** / 清理垃圾 / 图标去白边 |

完整轨迹见 [项目文档/版本清单.md](项目文档/版本清单.md)。

---

## 七、常见问题

**Q：安装很慢 / pip 报错？**
A：已默认配置国内镜像（CNB 源码镜像 / 清华 pip 源 / 清华 Debian apt 源 / 国内 DNS），无需额外设置。Debian rootfs 包已镜像到七牛云 `m.ebmma.com`（国内流量），App 通过七牛 `sources.json` 清单自动解析地址，换源无需重装。

**Q：想换模型或换 Key？**
A：App 内「配置」→ 模型 Tab → 选供应商 + 填 Key → 保存。支持自定义 OpenAI 兼容端点。

**Q：对话页提示"正在启动网关"很久？**
A：网关底层是 proot + Python，在手机上冷启动需要时间（这是 proot 架构特性）。v0.3.41 起应用启动即自动起网关，常驻后后续进对话页秒连。

**Q：和其他手机端方案有什么区别？**
A：本 App 自带完整 proot + Debian 运行环境，Hermes 本体在手机本地跑，不是"手机只当遥控器"的伪方案。

**Q：iOS 能用吗？**
A：本仓库聚焦安卓。iOS 因沙盒限制无法本地驻留 Hermes 进程，暂不提供支持。

---

## 八、未来 APP 计划（路线图）

> 维护态下的下一阶段主线，按优先级排序（来源：2026-07-17 臣哥与 Agent 共识）。

1. **网关常驻与崩溃自愈（性能主线）**：当前"卡"的根因是 proot 本身（无真实内核权限，系统调用全翻译），换 Debian 只能小幅优化。下一步重点——网关进程常驻不退出（减少冷启动）、断线自动重连、更清晰的健康态展示；目标是让对话响应明显变快。
2. **Skill 管理升级（v0.3.46 候选）**：已装列表 / 卸载 / 启用 + SOUL.md/USER.md 编辑器 + 临时 skill TTL 清理 + 「让 Agent 学习此 skill」按钮。
3. **分身 / 第二实例（v0.3.47 候选）**：独立端口（18790）+ 独立 HOME + SOUL.md，实现多 Agent 并行。
4. **✅ 更新源加固（v0.3.44 已完成）**：Debian rootfs 已镜像到七牛 `const/hermesmb`，并由 `sources.json` 中央清单管理，换源无需重发 App；七牛测试域名过期风险已通过 `const/hermesmb` 永久域名规避。
5. **文档与版本号常驻**：README/版本清单持续与代码同步（已对齐至 v0.3.45）；App 界面常驻版本号（首页页脚）仍待做（v0.3.46 候选）。

---

## 九、相关仓库

| 仓库 | 说明 |
|------|------|
| [`const1981/hermes-agent-mobile-zh`](https://github.com/const1981/hermes-agent-mobile-zh) | **本仓库** — Hermes 遥控器（维护态，v0.3.x 序列） |
| [`NousResearch/hermes-agent`](https://github.com/NousResearch/hermes-agent) | Hermes Agent 引擎（上游） |
| [`Binair-Dev/HermesAgentMobile`](https://github.com/Binair-Dev/HermesAgentMobile) | 原上游 Flutter 工程（MIT，已 Fork） |

---

## 许可证

版权所有 (C) 2026 李臣 (Li Chen)

本程序是自由软件：你可以根据自由软件基金会发布的 **GNU Affero 通用公共许可证（AGPL-3.0）** 的条款 —— 无论是许可证的第 3 版还是（由你选择的）任何后续版本 —— 重新分发和/或修改它。

本程序的发布是希望它能起到作用，但**没有任何担保**；甚至没有隐含的适销性或特定用途适用性的担保。详情请参见 GNU Affero 通用公共许可证。

你应该已经收到了本程序附带的 GNU Affero 通用公共许可证副本。如果没有，请访问 <https://www.gnu.org/licenses/>。

> **注意：** 本仓库所含的 Flutter/Dart/Kotlin 源代码及文档（"本程序"）是在 AGPL-3.0 下发布的。底层 `hermes-agent` 引擎（`NousResearch/hermes-agent`）为上游项目，采用 Apache 2.0 许可证；原上游 Flutter 工程（`Binair-Dev/HermesAgentMobile`）采用 MIT 许可证，其版权归原始作者所有。
