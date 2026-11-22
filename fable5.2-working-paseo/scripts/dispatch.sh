#!/usr/bin/env bash
# 经 paseo 派一个 Codex 工人，立即返回，stdout 只输出 agent id。
# 用法: dispatch.sh <任务ID> <sol|astra|完整模型id> <brief文件> [额外的 paseo run 参数...]
# 环境变量: FW_THINKING 覆盖 thinking 档位（默认 sol=high, astra=max）
set -euo pipefail

[ $# -ge 3 ] || { echo "用法: dispatch.sh <任务ID> <sol|astra|模型id> <brief文件> [paseo run 参数...]" >&2; exit 64; }
task="$1"; model="$2"; brief="$3"; shift 3

case "$model" in
  sol)   model="gpt-6.2-sol";   thinking="${FW_THINKING:-high}" ;;
  astra) model="gpt-6.2-astra"; thinking="${FW_THINKING:-max}" ;;
  *)     thinking="${FW_THINKING:-high}" ;;
esac
[ -s "$brief" ] || { echo "brief 不存在或为空: $brief" >&2; exit 64; }

out="$(paseo run \
  --provider "codex/$model" --thinking "$thinking" --mode full-access \
  --title "fw:$task" --label fw=worker --label "task=$task" \
  --no-wait --json "$@" -- "$(cat "$brief")")"

id="$(printf '%s' "$out" | jq -r '.agentId // empty' 2>/dev/null || true)"
[ -n "$id" ] || { echo "派工失败，paseo 输出:" >&2; printf '%s\n' "$out" >&2; exit 1; }
echo "$id"
