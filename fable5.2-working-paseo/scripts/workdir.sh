#!/usr/bin/env bash
# 工人 / 监工的工作文件夹：<项目根>/.tmp/.fable-working/<名字>/。<名字> 同时就是 paseo 会话名（工人 [Worker] <名字>，监工 [Supervisor] <名字>）。
# 用法:
#   workdir.sh list                                   列出已有的工作文件夹和各自的任务（派工前先看，判断是否同一件事）
#   workdir.sh ensure <名字> <任务ID> <一句话目标> [--merge]
#       不存在 → 新建（带 TASK.md），stdout 输出绝对路径
#       已存在且属于同一任务ID → 复用（返工）；属于别的任务 → 退出码 3，除非带 --merge（用户已同意合并）
#   workdir.sh log <名字> <一行记录>                  往 TASK.md 的 agent 记录追加一行
# 项目根 = 当前目录所在 git 仓库的顶层；不是 git 仓库就用当前目录。环境变量 FW_PROJECT 可覆盖。
set -euo pipefail

PROJECT="${FW_PROJECT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
ROOT="$PROJECT/.tmp/.fable-working"

check_name() {
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,47}$ ]] || {
    echo "名字不合规: '$1'（只用字母、数字、. _ -，≤48 字符，例如 pa-offset-probe）" >&2; exit 64; }
}
field() { sed -n "s/^- $2：//p" "$1" 2>/dev/null | head -1; }

cmd="${1:-}"; shift || true
case "$cmd" in
  list)
    [ -d "$ROOT" ] || { echo "（$ROOT 还不存在，没有已有任务）"; exit 0; }
    found=0
    for d in "$ROOT"/*/; do
      [ -d "$d" ] || continue; found=1
      n="$(basename "$d")"; t="$d/TASK.md"
      printf '%s\t任务=%s\t建立=%s\t目标=%s\n' "$n" "$(field "$t" 任务ID)" "$(field "$t" 建立)" "$(field "$t" 目标)"
    done
    [ "$found" = 1 ] || echo "（$ROOT 下没有已有任务）" ;;
  ensure)
    [ $# -ge 3 ] || { echo "用法: workdir.sh ensure <名字> <任务ID> <一句话目标> [--merge]" >&2; exit 64; }
    name="$1"; task="$2"; goal="$3"; merge="${4:-}"
    check_name "$name"
    wd="$ROOT/$name"
    if [ -d "$wd" ]; then
      old="$(field "$wd/TASK.md" 任务ID)"
      if [ "$old" != "$task" ] && [ "$merge" != "--merge" ]; then
        echo "工作文件夹已存在且属于任务 '${old:-?}'：$wd" >&2
        echo "是同一件事 → 先问用户是否合并，同意后加 --merge；不是 → 换一个新名字" >&2
        exit 3
      fi
      [ "$old" = "$task" ] || printf -- '- %s 并入任务 %s：%s\n' "$(date '+%F %T')" "$task" "$goal" >> "$wd/TASK.md"
    else
      mkdir -p "$wd"
      cat > "$wd/TASK.md" <<EOF
# $name

- paseo 会话名：[Worker] $name / [Supervisor] $name
- 任务ID：$task
- 目标：$goal
- 建立：$(date '+%F %T')

## 记录

EOF
    fi
    echo "$wd" ;;
  log)
    [ $# -ge 2 ] || { echo "用法: workdir.sh log <名字> <一行记录>" >&2; exit 64; }
    check_name "$1"
    [ -f "$ROOT/$1/TASK.md" ] || { echo "没有这个工作文件夹: $ROOT/$1" >&2; exit 1; }
    printf -- '- %s %s\n' "$(date '+%F %T')" "$2" >> "$ROOT/$1/TASK.md" ;;
  *)
    echo "用法: workdir.sh list | ensure <名字> <任务ID> <一句话目标> [--merge] | log <名字> <一行记录>" >&2; exit 64 ;;
esac
