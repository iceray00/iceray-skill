#!/usr/bin/env bash
# 启动一个监工（默认 Claude Code + deepseek-flash），由它去派 Codex 工人并盯到做完。输出监工的 agent id。
# 用法: supervise.sh <任务ID> <sol|astra|模型id> <brief文件> [paseo run 参数...]
# 环境变量: FW_SUPERVISOR(claude/deepseek-flash)
set -euo pipefail

[ $# -ge 3 ] || { echo "用法: supervise.sh <任务ID> <sol|astra|模型id> <brief文件> [paseo run 参数...]" >&2; exit 64; }
task="$1"; model="$2"; brief="$3"; shift 3
[ -s "$brief" ] || { echo "brief 不存在或为空: $brief" >&2; exit 64; }

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
brief="$(cd "$(dirname "$brief")" && pwd)/$(basename "$brief")"
sup="${brief%.md}.supervisor.md"

FW_SKILL_DIR="$SKILL_DIR" FW_TASK="$task" FW_MODEL="$model" FW_BRIEF="$brief" \
  perl -CSD -Mutf8 -pe 's/<SKILL_DIR>/$ENV{FW_SKILL_DIR}/g; s/<任务ID>/$ENV{FW_TASK}/g; s/<模型>/$ENV{FW_MODEL}/g; s/<brief路径>/$ENV{FW_BRIEF}/g' \
  "$SKILL_DIR/templates/supervisor-brief.md" > "$sup"

out="$(paseo run \
  --provider "${FW_SUPERVISOR:-claude/deepseek-flash}" --mode bypassPermissions \
  --title "fw:$task:supervisor" --label fw=supervisor --label "task=$task" \
  --no-wait --json "$@" -- "$(cat "$sup")")"
id="$(printf '%s' "$out" | jq -r '.agentId // empty' 2>/dev/null || true)"
[ -n "$id" ] || { echo "启动监工失败，paseo 输出:" >&2; printf '%s\n' "$out" >&2; exit 1; }
echo "$id"
