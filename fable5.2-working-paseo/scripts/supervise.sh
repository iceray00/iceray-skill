#!/usr/bin/env bash
# 启动一个监工（默认 Claude Code + deepseek-flash），由它去派 Codex 工人并盯到做完。输出监工的 agent id。
# 用法: supervise.sh <任务ID> <sol|astra|模型id> <brief文件> [--workdir <名字>] [--merge] [paseo run 参数...]
#   --workdir / --merge 同 dispatch.sh：监工（会话名 [Supervisor] <名字>）和它派的工人共用 .tmp/.fable-working/<名字>/
# 环境变量: FW_SUPERVISOR(claude/deepseek-flash)
set -euo pipefail

[ $# -ge 3 ] || { echo "用法: supervise.sh <任务ID> <sol|astra|模型id> <brief文件> [--workdir <名字>] [--merge] [paseo run 参数...]" >&2; exit 64; }
task="$1"; model="$2"; brief="$3"; shift 3
[ -s "$brief" ] || { echo "brief 不存在或为空: $brief" >&2; exit 64; }

name="$task"; merge=""; extra=()
while [ $# -gt 0 ]; do
  case "$1" in
    --workdir) name="$2"; shift 2 ;;
    --merge)   merge="--merge"; shift ;;
    *)         extra+=("$1"); shift ;;
  esac
done

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
brief="$(cd "$(dirname "$brief")" && pwd)/$(basename "$brief")"
sup="${brief%.md}.supervisor.md"
project="${FW_PROJECT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
goal="$(sed -n 's/^# *//p' "$brief" | head -1)"
wd="$(FW_PROJECT="$project" bash "$SKILL_DIR/scripts/workdir.sh" ensure "$name" "$task" "${goal:-$task}" $merge)"
wargs="--workdir $name${merge:+ --merge}"

FW_SKILL_DIR="$SKILL_DIR" FW_TASK="$task" FW_MODEL="$model" FW_BRIEF="$brief" FW_PROJECT="$project" FW_WD="$wd" FW_WARGS="$wargs" \
  perl -CSD -Mutf8 -pe 's/<SKILL_DIR>/$ENV{FW_SKILL_DIR}/g; s/<任务ID>/$ENV{FW_TASK}/g; s/<模型>/$ENV{FW_MODEL}/g; s/<brief路径>/$ENV{FW_BRIEF}/g; s/<项目根>/$ENV{FW_PROJECT}/g; s/<工作文件夹>/$ENV{FW_WD}/g; s/<工作参数>/$ENV{FW_WARGS}/g' \
  "$SKILL_DIR/templates/supervisor-brief.md" > "$sup"

out="$(paseo run \
  --provider "${FW_SUPERVISOR:-claude/deepseek-flash}" --mode bypassPermissions \
  --title "[Supervisor] $name" --label fw=supervisor --label "task=$task" --label "workdir=$name" \
  --cwd "$wd" --no-wait --json ${extra[@]+"${extra[@]}"} -- "$(cat "$sup")")"
id="$(printf '%s' "$out" | jq -r '.agentId // empty' 2>/dev/null || true)"
[ -n "$id" ] || { echo "启动监工失败，paseo 输出:" >&2; printf '%s\n' "$out" >&2; exit 1; }

# 监工是 Claude Code：确认它有自己的会话文件，没有挂到主脑的会话上（见 SKILL.md「Paseo 会话陷阱」）
case "${FW_SUPERVISOR:-claude/deepseek-flash}" in
  claude*)
    if ! chk="$(bash "$SKILL_DIR/scripts/check-session.sh" "$id" 2>&1)"; then
      printf '%s\n' "$chk" >&2
      if printf '%s' "$chk" | grep -q '^\[FAIL\]'; then
        paseo stop "$id" >/dev/null 2>&1
        echo "监工 $id 与主脑共用会话，已停下；不要给它发消息，交给用户决定是否归档" >&2
        exit 1
      fi
      echo "[warn] 没能确认监工的会话是否独立，照常继续" >&2
    fi ;;
esac
FW_PROJECT="$project" bash "$SKILL_DIR/scripts/workdir.sh" log "$name" "监工 $id（任务 $task）brief=$sup" || true
echo "$id"
