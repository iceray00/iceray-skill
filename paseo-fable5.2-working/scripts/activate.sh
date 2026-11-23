#!/usr/bin/env bash
# 激活 paseo-fable5.2-working 流程：初始化 .fable-working/、预检 paseo 与模型。
# 用法: activate.sh [项目目录，默认当前目录]
set -u

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$(cd "${1:-$PWD}" && pwd)" || { echo "项目目录不存在: ${1:-}" >&2; exit 64; }
fail=0

# 1. 初始化项目工作目录
mkdir -p "$PROJECT/.fable-working/briefs"
if [ ! -e "$PROJECT/.fable-working/ledger.md" ]; then
  FW_SKILL_DIR="$SKILL_DIR" perl -pe 's/<SKILL_DIR>/$ENV{FW_SKILL_DIR}/g' "$SKILL_DIR/templates/ledger.md" > "$PROJECT/.fable-working/ledger.md"
fi
echo "[ok]   工作目录: $PROJECT/.fable-working"
if git -C "$PROJECT" rev-parse --git-dir >/dev/null 2>&1; then
  exclude="$(git -C "$PROJECT" rev-parse --git-path info/exclude)"
  case "$exclude" in /*) ;; *) exclude="$PROJECT/$exclude" ;; esac
  if ! grep -qxF '.fable-working/' "$exclude" 2>/dev/null; then
    mkdir -p "$(dirname "$exclude")" && echo '.fable-working/' >> "$exclude"
    echo "[ok]   已把 .fable-working/ 加进 .git/info/exclude（仅本地生效）"
  fi
  echo "[ok]   git HEAD: $(git -C "$PROJECT" rev-parse --short HEAD 2>/dev/null || echo '无提交')"
else
  echo "[warn] 不是 git 仓库：验收时没有 git diff 可用，也不能用 worktree 隔离"
fi

# 2. 预检 paseo 与模型
if ! command -v paseo >/dev/null 2>&1; then
  echo "[FAIL] 找不到 paseo"; exit 1
fi
if ! paseo status >/dev/null 2>&1; then
  echo "[FAIL] paseo daemon 不可达（试试 paseo start）"; exit 1
fi
echo "[ok]   paseo daemon 可达"
codex_models="$(paseo provider models codex -q 2>/dev/null || paseo provider models codex 2>/dev/null)"
claude_models="$(paseo provider models claude 2>/dev/null)"
for m in gpt-6.2-sol gpt-6.2-astra; do
  if printf '%s' "$codex_models" | grep -q -- "$m"; then echo "[ok]   工人模型: codex/$m"
  else echo "[FAIL] codex 下没有模型 $m"; fail=1; fi
done
if printf '%s' "$claude_models" | grep -q -- "deepseek-flash"; then echo "[ok]   监工模型: claude/deepseek-flash"
else echo "[warn] claude 下没有 deepseek-flash：只能用直接派工（方式 A）"; fi

running="$(paseo ls --label fw=worker --json 2>/dev/null | jq -r '.[] | select(.status=="running") | "\(.shortId) \(.name)"' 2>/dev/null)"
[ -n "$running" ] && { echo "[info] 仍在运行的工人:"; printf '%s\n' "$running" | sed 's/^/         /'; }

# 3. 主脑的会话是否和别的 agent 共用（paseo 工具接口开 claude 子 agent 的陷阱，见 SKILL.md）
bash "$SKILL_DIR/scripts/check-session.sh" --caller

exit "$fail"
