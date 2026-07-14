#!/bin/bash
# ============================================================
#  Hermes 手机端一键安装脚本（安卓 Termux · 中文版 · 原创）
# ------------------------------------------------------------
#  设计思路（参考 amirghm/hermes-agent-mobile 的概念，但完全自己实现）：
#   · 手机本地运行 Hermes Agent 的调度层（思考链 / 工具调用 / 记忆 / 多轮对话）
#   · 仅「大模型推理」走云端 API，不在手机上跑任何模型
#   · 通过上游官方安装器安装 Agent 本体（本脚本不打包 Agent 代码）
#   · 装好后写入中文配置：可选 OpenRouter / 智谱 / DeepSeek / Kimi
#
#  用法：
#    bash <(curl -fsSL https://raw.githubusercontent.com/<你的账号>/hermes-agent-mobile-zh/main/scripts/install-termux.sh)
#
#  前置：手机已装好 Termux（建议 F-Droid 或 GitHub 版），并授予存储权限。
#        首次打开 Termux 建议先执行一次： pkg update && pkg upgrade -y
# ============================================================

set -e

# ---------- 颜色（printf 格式） ----------
R='\e[1;31m'; G='\e[1;32m'; Y='\e[1;33m'; B='\e[1;34m'; C='\e[1;36m'; W='\e[1;37m'; D='\e[0m'

header() {
  clear
  printf "\n"
  printf "  ${C}==================================================${D}\n"
  printf "  ${C}#${W}   Hermes 手机端一键安装（安卓 Termux）       ${C}#${D}\n"
  printf "  ${C}#${W}   本地跑调度  ·  云端跑推理  ·  中文配置     ${C}#${D}\n"
  printf "  ${C}==================================================${D}\n"
  printf "\n"
}
step() { printf "\n  ${B}=== 第 $1 步：$2 ===${D}\n"; }
ok()   { printf "  ${G}✓${D} $1\n"; }
skip() { printf "  ${Y}~${D} $1（已存在，跳过）\n"; }
warn() { printf "  ${Y}!${D} $1\n"; }
fail() { printf "  ${R}✗${D} $1\n"; exit 1; }
log()  { printf "  $1\n"; }
ask()       { printf "  ${W}$1${D} "; read -r "$2"; }
ask_secret(){ printf "  ${W}$1${D} "; read -r -s "$2"; printf "\n"; }
trim() { printf "%s" "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }

# 必须在 bash 下运行（Termux 默认就是 bash，但防止用 sh 调起）
if [ -z "${BASH_VERSION:-}" ]; then
  echo "错误：请使用 bash 运行本脚本，不要用 sh。"
  echo "正确用法： bash <(curl -fsSL <脚本地址>)"
  exit 1
fi

# 环境检查：是否 Termux
if [ -d "/data/data/com.termux" ]; then
  ok "检测到 Termux 环境"
else
  warn "未检测到 Termux（/data/data/com.termux 不存在）。本脚本面向安卓 Termux。"
  ask "仍要继续吗？[y/N]:" _c
  case "$_c" in y|Y|yes|YES) ;; *) exit 0 ;; esac
fi

header

# ============================================================
#  第 0 步：选择大模型提供商（仅推理走云端）
# ============================================================
PROVIDER=""; BASE_URL=""; MODEL=""; KEY_ENV=""; KEY_PROMPT=""

while [ -z "$PROVIDER" ]; do
  printf "  ${C}请选择大模型提供商（Agent 仍跑在手机本地，只有推理请求发往云端）：${D}\n"
  printf "    ${C}1)${D} OpenRouter   （推荐 · 聚合多家，含免费 ${W}xiaomi/mimo-v2.5${D}）\n"
  printf "    ${C}2)${D} 智谱 GLM     （bigmodel.cn，国内）\n"
  printf "    ${C}3)${D} DeepSeek     （深度求索，国内）\n"
  printf "    ${C}4)${D} Kimi         （月之暗面，国内）\n"
  printf "    ${C}5)${D} 自定义 OpenAI 兼容端点\n"
  printf "\n"
  ask "输入序号 [1]:" CHOICE
  CHOICE="$(trim "$CHOICE")"; [ -z "$CHOICE" ] && CHOICE=1
  case "$CHOICE" in
    1)
      PROVIDER="openrouter"; BASE_URL="https://openrouter.ai/api/v1"
      MODEL="xiaomi/mimo-v2.5"; KEY_ENV="OPENROUTER_API_KEY"; KEY_PROMPT="OpenRouter API Key"
      ;;
    2)
      PROVIDER="custom"; BASE_URL="https://open.bigmodel.cn/api/paas/v1"
      MODEL="glm-4.5-air"; KEY_ENV="ZHIPU_API_KEY"; KEY_PROMPT="智谱 GLM API Key"
      ;;
    3)
      PROVIDER="custom"; BASE_URL="https://api.deepseek.com/v1"
      MODEL="deepseek-chat"; KEY_ENV="DEEPSEEK_API_KEY"; KEY_PROMPT="DeepSeek API Key"
      ;;
    4)
      PROVIDER="custom"; BASE_URL="https://api.moonshot.cn/v1"
      MODEL="moonshot-v1-8k"; KEY_ENV="KIMI_API_KEY"; KEY_PROMPT="Kimi API Key"
      ;;
    5)
      PROVIDER="custom"
      ask "自定义 base_url（例如 https://api.xxx.com/v1）:" BASE_URL
      BASE_URL="$(trim "$BASE_URL")"; [ -z "$BASE_URL" ] && fail "base_url 不能为空"
      ask "自定义 API Key 对应的环境变量名 [OPENAI_API_KEY]:" KEY_ENV
      KEY_ENV="$(trim "$KEY_ENV")"; [ -z "$KEY_ENV" ] && KEY_ENV="OPENAI_API_KEY"
      KEY_PROMPT="自定义 API Key（将写入 .env 的 ${KEY_ENV}）"
      ;;
    *) warn "请输入 1-5"; continue ;;
  esac
done

# 收集密钥（不回显）
API_KEY=""
while [ -z "$API_KEY" ]; do
  ask_secret "$KEY_PROMPT:" API_KEY
  API_KEY="$(trim "$API_KEY")"
done

# 确认 / 修改默认模型
printf "  ${W}当前默认模型：${C}%s${D}\n" "$MODEL"
ask "模型名（直接回车保留默认）:" MODEL_IN
MODEL_IN="$(trim "$MODEL_IN")"; [ -n "$MODEL_IN" ] && MODEL="$MODEL_IN"

# Telegram 网关（可选）
TELEGRAM_TOKEN=""
ask "Telegram Bot Token（可回车跳过，只使用本地命令行）:" TELEGRAM_TOKEN
TELEGRAM_TOKEN="$(trim "$TELEGRAM_TOKEN")"

printf "\n"
ok "配置收集完成：provider=${PROVIDER}  model=${MODEL}"
if [ -n "$TELEGRAM_TOKEN" ]; then log "Telegram 网关：将启用"; else log "Telegram 网关：跳过（仅本地 CLI）"; fi

# ============================================================
#  第 1 步：设置 pip 国内镜像（清华源，加速 ARM 安装）
# ============================================================
step 1 "设置 pip 国内镜像（清华源）"
export PIP_INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple"
export PIP_TRUSTED_HOST="pypi.tuna.tsinghua.edu.cn"
ok "已临时设置清华 pip 镜像（仅本次安装生效；若镜像陈旧可改回官方源）"

# ============================================================
#  第 2 步：调用上游官方安装器（--skip-setup 不跑交互向导）
# ============================================================
step 2 "调用 Hermes Agent 官方安装器"
if command -v hermes >/dev/null 2>&1; then
  skip "Hermes 已安装，跳过官方安装器（如要重装请先卸载）"
else
  log "官方安装器将：装 Termux 编译依赖 → 建 Python venv → pip 安装 hermes-agent（Termux 精简版，已排除本地语音依赖）"
  INSTALLER="$(mktemp)"
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh -o "$INSTALLER"
  bash "$INSTALLER" --skip-setup
  rm -f "$INSTALLER"
  ok "Hermes Agent 安装完成"
fi

# 确认 hermes 命令可用
if ! command -v hermes >/dev/null 2>&1; then
  warn "当前 PATH 未找到 hermes 命令。若安装曾报错，可手动进入："
  warn "  cd ~/.hermes/hermes-agent && source venv/bin/activate && hermes"
fi

# ============================================================
#  第 3 步：写入中文配置（~/.hermes）
# ============================================================
step 3 "写入 Hermes 配置（~/.hermes）"
mkdir -p ~/.hermes/logs ~/.hermes/sessions ~/.hermes/cron ~/.hermes/memories ~/.hermes/skills

# .env：只放密钥类敏感信息
ENV_FILE=~/.hermes/.env
touch "$ENV_FILE"; chmod 600 "$ENV_FILE"
TMP_ENV="$(mktemp)"
grep -v -E "^${KEY_ENV}=" "$ENV_FILE" > "$TMP_ENV" 2>/dev/null || true
{ cat "$TMP_ENV"; printf "%s=%s\n" "$KEY_ENV" "$API_KEY"; } > "$ENV_FILE"
rm -f "$TMP_ENV"; chmod 600 "$ENV_FILE"

# config.yaml：非敏感配置；密钥用 ${VAR} 引用，避免明文写在配置里
API_KEY_REF="\${${KEY_ENV}}"   # 生成字面量 ${OPENROUTER_API_KEY} 之类，供 Hermes 运行时解析
CONFIG_FILE=~/.hermes/config.yaml
cat > "$CONFIG_FILE" <<CONFIG_EOF
# Hermes 配置（手机本地运行 · 云端推理）
# 说明：Agent 调度层跑在你的手机本地（Termux），只有大模型推理请求发往云端。
model:
  provider: ${PROVIDER}
  model: ${MODEL}
  base_url: ${BASE_URL}
  # 密钥从 ~/.hermes/.env 读取，下面用 ${变量名} 引用，运行时由 Hermes 解析
  api_key: ${API_KEY_REF}

agent:
  max_turns: 10

# 进阶：记忆 / 技能目录已建好；更多配置见官方文档
# https://hermes-agent.nousresearch.com
CONFIG_EOF
ok "配置已写入：$CONFIG_FILE"

# ============================================================
#  第 4 步：可选启动 Telegram 网关
# ============================================================
if [ -n "$TELEGRAM_TOKEN" ]; then
  step 4 "配置并启动 Telegram 网关"
  TMP_ENV="$(mktemp)"
  grep -v -E "^TELEGRAM_BOT_TOKEN=" "$ENV_FILE" > "$TMP_ENV" 2>/dev/null || true
  { cat "$TMP_ENV"; printf "TELEGRAM_BOT_TOKEN=%s\n" "$TELEGRAM_TOKEN"; } > "$ENV_FILE"
  rm -f "$TMP_ENV"; chmod 600 "$ENV_FILE"
  mkdir -p ~/.hermes/logs
  log "后台启动网关：hermes gateway"
  nohup hermes gateway > ~/.hermes/logs/gateway.log 2>&1 &
  sleep 3
  ok "Telegram 网关已尝试启动（日志：~/.hermes/logs/gateway.log）"
  log "去 Telegram 给机器人发 /start 即可对话。"
else
  step 4 "跳过 Telegram 网关"
  log "未配置 Telegram。需要时手动运行：hermes gateway"
fi

# ============================================================
#  完成
# ============================================================
header
printf "  ${G}✅ 安装完成！${D}\n"
printf "\n"
printf "  ${W}常用命令：${D}\n"
printf "    ${C}hermes${D}          启动本地 Hermes 对话\n"
printf "    ${C}hermes setup${D}    交互式配置（改模型 / 密钥 / 网关）\n"
printf "    ${C}hermes gateway${D}   启动 Telegram 等消息网关\n"
printf "\n"
printf "  ${W}文档：${D}\n"
printf "    后台保活：本项目 docs/后台保活指南.md\n"
printf "    官方文档：https://hermes-agent.nousresearch.com\n"
printf "\n"
printf "  ${Y}⚠ 安卓会杀后台：按 docs/后台保活指南.md 关闭电池优化 / 开启唤醒锁，否则锁屏后 Agent 会停。${D}\n"
printf "\n"

ask "是否现在启动 Hermes 对话？[Y/n]:" _start
case "$_start" in n|N|no|NO) ;; *) exec hermes ;; esac
