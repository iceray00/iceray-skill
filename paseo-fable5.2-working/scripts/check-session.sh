#!/usr/bin/env bash
# 查 paseo agent 有没有和别的 agent（尤其是主脑）共用同一个 Claude Code 会话文件。只读。
# 用法:
#   check-session.sh <agent-id>   这个 agent 的会话是否独立；退出码 0 独立  1 与主脑或别的 agent 共用  2 查不到
#   check-session.sh --caller     主脑自己：会话 id、有没有和别人共用、用工具接口开 claude 子 agent 会不会漏会话
#   check-session.sh --audit      全部 agent 里共用同一会话 id 的分组
# 背景（paseo 0.17.2 实测）：工具接口 create_agent 开同一 provider 的子 agent 时，会把调用者的
#   config.providerOptions 原样复制过去；调用者里若有 extraArgs.resume=<会话id>，子 agent 就以
#   --resume 同一个会话启动，写进同一个 .jsonl。命令行 paseo run 不走这段逻辑。
# 环境变量: PASEO_HOME（默认 ~/.paseo） FW_SESSION_WAIT（等新 agent 出现会话 id 的秒数，默认 60）
set -u

PH="${PASEO_HOME:-$HOME/.paseo}"
AG="$PH/agents"
[ -d "$AG" ] || { echo "[FAIL] 找不到 paseo 的 agent 记录目录: $AG（设 PASEO_HOME）" >&2; exit 2; }

record() { # 完整 id 或短 id → 记录文件
  local id="$1" full f
  f="$(ls "$AG"/*/"$id"*.json 2>/dev/null | head -1)"
  if [ -z "$f" ]; then
    full="$(paseo inspect "$id" --json 2>/dev/null | jq -r '.Id // empty' 2>/dev/null)"
    [ -n "$full" ] && f="$(ls "$AG"/*/"$full".json 2>/dev/null | head -1)"
  fi
  printf '%s' "$f"
}
sid_of()   { jq -r '.persistence.sessionId // empty' "$1" 2>/dev/null; }
prov_of()  { jq -r '.persistence.provider // .provider // empty' "$1" 2>/dev/null; }
title_of() { jq -r '.title // .config.title // .persistence.metadata.title // "?"' "$1" 2>/dev/null; }
sharers()  { # sharers <会话id> <排除的记录文件...> → 同会话的其他 agent
  local sid="$1"; shift
  grep -l -- "\"sessionId\":\"$sid\"\|\"sessionId\": \"$sid\"" "$AG"/*/*.json 2>/dev/null | while read -r f; do
    skip=0; for x in "$@"; do [ "$f" = "$x" ] && skip=1; done
    [ "$skip" = 1 ] && continue
    [ "$(sid_of "$f")" = "$sid" ] && echo "         $(basename "$f" .json | cut -c1-7)  $(prov_of "$f")  $(title_of "$f" | cut -c1-50)"
  done
}
caller_sids() {
  [ -n "${CLAUDE_CODE_SESSION_ID:-}" ] && echo "$CLAUDE_CODE_SESSION_ID"
  if [ -n "${PASEO_AGENT_ID:-}" ]; then
    local f; f="$(record "$PASEO_AGENT_ID")"; [ -n "$f" ] && sid_of "$f"
  fi
}

case "${1:-}" in
  --audit)
    jq -r 'select(.persistence.sessionId != null) | [.persistence.sessionId, .id[0:7], (.persistence.provider // "?"), ((.title // .persistence.metadata.title // "?") | tostring | .[0:50])] | @tsv' "$AG"/*/*.json 2>/dev/null \
      | sort | awk -F'\t' '{n[$1]++; l[$1]=l[$1] "\n         " $2 "  " $3 "  " $4} END {for (s in n) if (n[s] > 1) {print "[warn] 会话 " s " 被 " n[s] " 个 agent 共用:" l[s]; bad=1} if (!bad) print "[ok]   没有共用会话的 agent"}'
    ;;
  --caller)
    [ -n "${PASEO_AGENT_ID:-}" ] || { echo "[info] 当前会话不是 paseo agent（没有 PASEO_AGENT_ID），工具接口问题不适用"; exit 0; }
    f="$(record "$PASEO_AGENT_ID")"
    [ -n "$f" ] || { echo "[warn] 找不到主脑自己的 paseo 记录（$PASEO_AGENT_ID）"; exit 2; }
    sid="$(sid_of "$f")"
    echo "[ok]   主脑: paseo agent ${PASEO_AGENT_ID:0:7}，会话 ${sid:-未知}"
    others="$(sharers "$sid" "$f")"
    if [ -n "$others" ]; then
      echo "[warn] 主脑的会话文件还被这些 agent 写过（不要再给它们发消息、不要在它们的标签页打字）:"; printf '%s\n' "$others"
    fi
    resume="$(jq -r '.config.providerOptions.extraArgs.resume // empty' "$f" 2>/dev/null)"
    if [ -n "$resume" ]; then
      echo "[warn] 主脑的 providerOptions 带着 resume=$resume：用工具接口 create_agent 开的 claude 子 agent 会继承它、写进主脑的会话"
    else
      echo "[info] 主脑的 providerOptions 现在不带 resume；但重启 / 恢复后可能会带上，规则照样不变：claude 子 agent 只用 paseo run"
    fi
    ;;
  ""|-h|--help) sed -n '2,10p' "$0"; exit 64 ;;
  *)
    id="$1"; waited=0; f=""; sid=""
    while :; do
      f="$(record "$id")"; [ -n "$f" ] && sid="$(sid_of "$f")"
      [ -n "$sid" ] && break
      [ "$waited" -ge "${FW_SESSION_WAIT:-60}" ] && { echo "[warn] agent $id 还没有会话 id（记录: ${f:-无}）"; exit 2; }
      sleep 3; waited=$((waited + 3))
    done
    bad=0
    for c in $(caller_sids | sort -u); do
      [ "$sid" = "$c" ] && { echo "[FAIL] agent ${id:0:7}（$(prov_of "$f")）用的就是主脑的会话 $sid"; bad=1; }
    done
    others="$(sharers "$sid" "$f")"
    [ -n "$others" ] && { echo "[FAIL] agent ${id:0:7} 的会话 $sid 还被这些 agent 用着:"; printf '%s\n' "$others"; bad=1; }
    [ "$bad" = 0 ] && echo "[ok]   agent ${id:0:7}（$(prov_of "$f")）会话独立: $sid"
    exit "$bad"
    ;;
esac
