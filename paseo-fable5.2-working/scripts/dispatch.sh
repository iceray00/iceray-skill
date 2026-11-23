#!/usr/bin/env bash
# 经 paseo 派一个工人，立即返回，stdout 只输出 agent id。
# 用法: dispatch.sh <任务ID> <sol|astra|模型id|provider/模型> <brief文件> [额外的 paseo run 参数...]
#   sol / astra / 模型id  → Codex 工人（codex/<模型>，full-access）
#   provider/模型         → 照 paseo profile 的写法原样使用；mode 和 thinking 只在环境变量里给了才传
# 环境变量: FW_THINKING 覆盖 thinking 档位（默认 sol=high, astra=max）  FW_MODE 覆盖 mode（Codex 默认 full-access）
set -euo pipefail

[ $# -ge 3 ] || { echo "用法: dispatch.sh <任务ID> <sol|astra|模型id|provider/模型> <brief文件> [paseo run 参数...]" >&2; exit 64; }
task="$1"; model="$2"; brief="$3"; shift 3

case "$model" in
  sol)   provider="codex/gpt-6.2-sol";   thinking="${FW_THINKING:-high}"; mode="${FW_MODE:-full-access}" ;;
  astra) provider="codex/gpt-6.2-astra"; thinking="${FW_THINKING:-max}";  mode="${FW_MODE:-full-access}" ;;
  */*)   provider="$model";              thinking="${FW_THINKING:-}";     mode="${FW_MODE:-}" ;;
  *)     provider="codex/$model";        thinking="${FW_THINKING:-high}"; mode="${FW_MODE:-full-access}" ;;
esac
[ -s "$brief" ] || { echo "brief 不存在或为空: $brief" >&2; exit 64; }

opts=(--provider "$provider")
[ -n "$thinking" ] && opts+=(--thinking "$thinking")
[ -n "$mode" ] && opts+=(--mode "$mode")

out="$(paseo run "${opts[@]}" \
  --title "[Worker] $task" --label fw=worker --label "task=$task" \
  --no-wait --json "$@" -- "$(cat "$brief")")"

id="$(printf '%s' "$out" | jq -r '.agentId // empty' 2>/dev/null || true)"
[ -n "$id" ] || { echo "派工失败，paseo 输出:" >&2; printf '%s\n' "$out" >&2; exit 1; }
echo "$id"
