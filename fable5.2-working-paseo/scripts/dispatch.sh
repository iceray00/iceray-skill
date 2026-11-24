#!/usr/bin/env bash
# 经 paseo 派一个工人，立即返回，stdout 只输出 agent id。
# 用法: dispatch.sh <任务ID> <sol|astra|模型id|provider/模型> <brief文件> [--workdir <名字>] [--merge] [额外的 paseo run 参数...]
#   sol / astra / 模型id  → Codex 工人（codex/<模型>，full-access）
#   provider/模型         → 照 paseo profile 的写法原样使用；mode 和 thinking 只在环境变量里给了才传
#   --workdir <名字>  工作文件夹 .tmp/.fable-working/<名字>/，也是 paseo 会话名 [Worker] <名字>（不给就用任务ID）
#   --merge           名字已被别的任务占用、且用户已同意合并时才加
# 环境变量: FW_THINKING 覆盖 thinking 档位（默认 sol=high, astra=max）  FW_MODE 覆盖 mode（Codex 默认 full-access）
set -euo pipefail

[ $# -ge 3 ] || { echo "用法: dispatch.sh <任务ID> <sol|astra|模型id|provider/模型> <brief文件> [--workdir <名字>] [--merge] [paseo run 参数...]" >&2; exit 64; }
task="$1"; model="$2"; brief="$3"; shift 3
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

name="$task"; merge=""; extra=()
while [ $# -gt 0 ]; do
  case "$1" in
    --workdir) name="$2"; shift 2 ;;
    --merge)   merge="--merge"; shift ;;
    *)         extra+=("$1"); shift ;;
  esac
done

case "$model" in
  sol)   provider="codex/gpt-6.2-sol";   thinking="${FW_THINKING:-high}"; mode="${FW_MODE:-full-access}" ;;
  astra) provider="codex/gpt-6.2-astra"; thinking="${FW_THINKING:-max}";  mode="${FW_MODE:-full-access}" ;;
  */*)   provider="$model";              thinking="${FW_THINKING:-}";     mode="${FW_MODE:-}" ;;
  *)     provider="codex/$model";        thinking="${FW_THINKING:-high}"; mode="${FW_MODE:-full-access}" ;;
esac
[ -s "$brief" ] || { echo "brief 不存在或为空: $brief" >&2; exit 64; }
brief="$(cd "$(dirname "$brief")" && pwd)/$(basename "$brief")"

project="${FW_PROJECT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
goal="$(sed -n 's/^# *//p' "$brief" | head -1)"
wd="$(FW_PROJECT="$project" bash "$SKILL_DIR/scripts/workdir.sh" ensure "$name" "$task" "${goal:-$task}" $merge)"

prompt="## 工作文件夹

- 项目根目录：$project（下文的相对路径都相对它）
- 你的工作文件夹：$wd
- 临时文件、日志、草稿、中间产出都放在工作文件夹里，不要放 /tmp 或项目里别的地方。
- 项目代码照常在项目根目录下按「文件范围」修改。

$(cat "$brief")"

opts=(--provider "$provider")
[ -n "$thinking" ] && opts+=(--thinking "$thinking")
[ -n "$mode" ] && opts+=(--mode "$mode")

out="$(paseo run "${opts[@]}" \
  --title "[Worker] $name" --label fw=worker --label "task=$task" --label "workdir=$name" \
  --cwd "$wd" --no-wait --json ${extra[@]+"${extra[@]}"} -- "$prompt")"

id="$(printf '%s' "$out" | jq -r '.agentId // empty' 2>/dev/null || true)"
[ -n "$id" ] || { echo "派工失败，paseo 输出:" >&2; printf '%s\n' "$out" >&2; exit 1; }
FW_PROJECT="$project" bash "$SKILL_DIR/scripts/workdir.sh" log "$name" "工人 $id（$provider，任务 $task）brief=$brief" || true
echo "$id"
