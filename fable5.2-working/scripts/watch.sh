#!/usr/bin/env bash
# 守候一个 paseo agent 直到它真正停下。
#   429 / 限流              → 退避后发消息让它从中断处继续
#   回复吐完但这一轮不结束  → 打断它；最后一段是完整汇报就算做完，否则返回
#   其他错误                → 立刻返回，交给主脑判断
# 用法: watch.sh <agent-id> [--send <消息文件>]
#   --send  先把文件内容发给 agent（返工 / 让它续做），再守候
# 退出码: 0 做完  2 非限流错误（含等待权限）  3 等待超时仍在跑  4 限流重试用尽  5 卡住已打断、没有完整汇报
# 环境变量: FW_MAX_NUDGES(8)  FW_WAIT_TIMEOUT(3600 秒)  FW_POLL(300 秒)  FW_STALL_SECS(600 秒)
#           FW_BACKOFF(60 秒，每次翻倍，上限 600)  FW_RATE_RE  FW_DONE_RE
set -u

usage() { echo "用法: watch.sh <agent-id> [--send <消息文件>]" >&2; exit 64; }
id="${1:-}"; [ -n "$id" ] || usage; shift
send_file=""
if [ $# -gt 0 ]; then
  { [ "$1" = "--send" ] && [ $# -eq 2 ]; } || usage
  send_file="$2"
  [ -s "$send_file" ] || { echo "消息文件不存在或为空: $send_file" >&2; exit 64; }
fi

MAX_NUDGES="${FW_MAX_NUDGES:-8}"
WAIT_TIMEOUT="${FW_WAIT_TIMEOUT:-3600}"
POLL="${FW_POLL:-300}"
STALL_SECS="${FW_STALL_SECS:-600}"
backoff="${FW_BACKOFF:-60}"
RATE_RE="${FW_RATE_RE:-(^|[^0-9])429([^0-9]|$)|too many requests|rate[ _-]?limit|overloaded|限流|请求过多}"
DONE_RE="${FW_DONE_RE:-状态[:：][[:space:]]*(完成|部分完成|受阻)}"
# 这句话里不能出现会匹配 RATE_RE 的词
NUDGE='上一轮被接口错误打断了。请从中断的地方继续完成原任务，不要从头重做；做完后按原 brief 约定的格式汇报。'

logs()      { paseo logs "$id" "$@" 2>/dev/null; }
progress()  { logs | sort -u | cksum; }   # 去重后的指纹：上游重试时重复吐出同一段回复不算进展
last_text() { logs --filter text --tail 1; }

# paseo 会把 agent 之间的消息排队约 2 秒再投递；等它真正进了时间线再去 wait，否则会读到旧状态
send() {
  local before i
  before="$(logs | cksum)"
  paseo send "$id" --no-wait "$@" >/dev/null 2>&1 || return 1
  for i in 1 2 3 4 5 6 7 8 9 10; do
    sleep 1
    [ "$(logs | cksum)" != "$before" ] && return 0
  done
  return 0
}

report() { # report <退出码> <结果> [说明]
  echo "FW_WATCH result=$2 agent=$id status=${status:-unknown} nudges=$nudges${3:+ note=$3}"
  if [ "${status:-}" = error ]; then
    echo "--- 错误"; printf '%s\n' "$msg"
    echo "--- 最近活动"; logs --tail 5
  else
    echo "--- 最近活动"
    if [ -n "${msg:-}" ]; then printf '%s\n' "$msg"; else printf '%s\n' "${res:-}"; fi
  fi
  exit "$1"
}

nudges=0; status=""; msg=""; res=""
if [ -n "$send_file" ]; then
  send --prompt-file "$send_file" || { msg="paseo send 失败"; report 2 ERROR; }
fi
start=$SECONDS; fp="$(progress)"; fp_at=$SECONDS

while :; do
  res="$(paseo wait "$id" --timeout "$POLL" --json 2>&1)"
  status="$(jq -r '.status // empty' <<<"$res" 2>/dev/null || true)"
  msg="$(jq -r '.message // empty' <<<"$res" 2>/dev/null || true)"

  case "$status" in
    idle) report 0 DONE ;;
    timeout)
      cur="$(progress)"
      if [ "$cur" != "$fp" ]; then fp="$cur"; fp_at=$SECONDS; fi
      # 最后一条是文字（不是还在跑的工具调用）且长时间没有新内容：上游的流没有收尾，这一轮不会自己结束
      if [ $((SECONDS - fp_at)) -ge "$STALL_SECS" ] && [ "$(logs --tail 1)" = "$(last_text)" ]; then
        paseo stop "$id" >/dev/null 2>&1
        if last_text | grep -qE "$DONE_RE"; then report 0 DONE stalled-after-report; fi
        report 5 STALLED
      fi
      [ $((SECONDS - start)) -ge "$WAIT_TIMEOUT" ] && report 3 TIMEOUT
      continue ;;
    error) ;;   # 这时 message 就是失败原因本身，下面判断是不是限流
    permission) report 2 PERMISSION ;;
    *) report 2 ERROR ;;   # paseo 自己出错：daemon 不可达、agent 不存在……
  esac

  grep -qiE "$RATE_RE" <<<"$msg" || report 2 ERROR
  [ "$nudges" -ge "$MAX_NUDGES" ] && report 4 RATE_LIMIT_EXHAUSTED

  nudges=$((nudges + 1))
  echo "[watch] 限流，第 $nudges/$MAX_NUDGES 次：等待 ${backoff}s 后让 agent 继续" >&2
  sleep "$backoff"
  backoff=$((backoff * 2)); [ "$backoff" -gt 600 ] && backoff=600
  send "$NUDGE" || { msg="paseo send 失败"; report 2 ERROR; }
  fp="$(progress)"; fp_at=$SECONDS
done
