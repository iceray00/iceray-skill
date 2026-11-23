#!/usr/bin/env bash
# 把本仓库里的 skill 安装成 Claude Code 的用户级 skill。只复制文件，不改任何配置。可重复执行。
# 用法: install.sh [--config-dir <Claude Code 配置目录>] [--agents] <skill>... | --all | --list
#   默认配置目录: $CLAUDE_CONFIG_DIR，未设置则 ~/.claude
#   --agents  另外装一份到 ~/.agents/skills/（paseo 自带的 skill 也装在这里，Codex 等 provider 从这里读）
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
all=0; list=0; agents=0; names=()
usage() { echo "用法: install.sh [--config-dir <目录>] [--agents] <skill>... | --all | --list" >&2; exit 64; }
available() { for d in "$REPO"/*/; do [ -f "$d/SKILL.md" ] && basename "$d"; done; }

while [ $# -gt 0 ]; do
  case "$1" in
    --config-dir) [ $# -ge 2 ] || usage; CFG="$2"; shift 2 ;;
    --agents) agents=1; shift ;;
    --all) all=1; shift ;;
    --list) list=1; shift ;;
    -*) usage ;;
    *) names+=("${1%/}"); shift ;;
  esac
done

if [ "$list" = 1 ]; then available; exit 0; fi
if [ "$all" = 1 ]; then mapfile -t names < <(available); fi
[ "${#names[@]}" -gt 0 ] || { echo "要装哪个 skill？可选:" >&2; available | sed 's/^/  /' >&2; usage; }
for name in "${names[@]}"; do
  [ -f "$REPO/$name/SKILL.md" ] || { echo "[FAIL] 仓库里没有 skill: $name" >&2; exit 1; }
done

mkdir -p "$CFG/skills"
roots=("$(cd "$CFG/skills" && pwd)")
if [ "$agents" = 1 ]; then
  mkdir -p "$HOME/.agents/skills"
  roots+=("$(cd "$HOME/.agents/skills" && pwd)")
fi

for name in "${names[@]}"; do
  for root in "${roots[@]}"; do
    dest="$root/$name"
    rm -rf "$dest.new"
    cp -R "$REPO/$name" "$dest.new"
    find "$dest.new" -name '*.sh' -exec chmod +x {} +
    if [ -e "$dest" ]; then
      echo "[info] 覆盖已有安装: $dest"
      rm -rf "$dest"
    fi
    mv "$dest.new" "$dest"
    echo "[ok]   已安装: $dest"
  done
done

echo
echo "完成。已经开着的会话需要重启才会加载新 skill；之后输入 /<skill 名> 使用。"
