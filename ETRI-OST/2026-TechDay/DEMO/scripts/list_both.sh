#!/usr/bin/env bash
# 같은 요청을 세션 헤더 없이 그리고 붙여서, 구 스펙과 신 스펙에 보내고 비교한다.
#
# 2단계의 증거다. "세션 헤더가 없다" 는 요청 쪽 사실이라 응답만 봐서는 알 수 없다.
# 네 칸을 다 채워야 호환 규칙이 보인다. 구 클라이언트는 신 서버에 연결되고 신
# 클라이언트는 구 서버에 못 붙는다. 그 방향이 이 표에서 읽힌다.
set -uo pipefail
PY="${OST_PY:-$HOME/.cache/ost-demo/venv/bin/python}"
OLD_PORT="${OST_OLD_PORT:-8100}"
NEW_PORT="${OST_NEW1_PORT:-8200}"

if { [ -t 1 ] || [ "${OST_COLOR:-0}" = "1" ]; } && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RST=$'\033[0m'
  GREEN=$'\033[32m'; RED=$'\033[31m'; CYAN=$'\033[36m'; YEL=$'\033[33m'
else BOLD=; DIM=; RST=; GREEN=; RED=; CYAN=; YEL=; fi

H='Content-Type: application/json'
A='Accept: application/json, text/event-stream'
META='"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientCapabilities":{}}'
# tools/list 로 개수를 세는 대신 도구를 실제로 호출한다. HTTP 코드가 아니라
# 과제명이 뜨느냐 안 뜨느냐로 동작 여부가 보인다.
CALL='"name":"get_project","arguments":{"과제코드":"2026-AI-013"}'
BODY="{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{$CALL,$META}}"

# 한글은 두 칸을 차지해서 printf %-Ns 로는 열이 안 맞는다. 표시 폭으로 채운다.
pad() {
  local text=$1 want=$2 w=0 ch i
  for (( i=0; i<${#text}; i++ )); do
    ch=${text:i:1}
    if [[ "$ch" == [[:ascii:]] ]]; then w=$((w+1)); else w=$((w+2)); fi
  done
  printf '%s' "$text"
  while [ "$w" -lt "$want" ]; do printf ' '; w=$((w+1)); done
}

# 구 스펙 서버에서 세션을 하나 연다. 그 헤더를 붙인 쪽 줄에 쓴다.
open_session() {
  local sid
  sid=$(curl -s -D- -o /dev/null --max-time 3 -X POST "http://127.0.0.1:$OLD_PORT/mcp" -H "$H" -H "$A" \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"ost-demo","version":"1"}}}' \
    2>/dev/null | awk -F': ' 'tolower($1)=="mcp-session-id"{gsub(/\r/,"",$2); print $2}')
  [ -n "$sid" ] || return 1
  curl -s -o /dev/null --max-time 3 -X POST "http://127.0.0.1:$OLD_PORT/mcp" -H "$H" -H "$A" \
    -H "mcp-session-id: $sid" -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' 2>/dev/null
  printf '%s' "$sid"
}

# ask <포트> [세션ID] -> "색<TAB>문구"
ask() {
  local port=$1 sid=${2:-} out code body
  if [ -n "$sid" ]; then
    out=$(curl -s -w '\n%{http_code}' --max-time 3 -X POST "http://127.0.0.1:$port/mcp" \
      -H "$H" -H "$A" -H "mcp-session-id: $sid" -d "$BODY" 2>/dev/null)
  else
    out=$(curl -s -w '\n%{http_code}' --max-time 3 -X POST "http://127.0.0.1:$port/mcp" \
      -H "$H" -H "$A" -d "$BODY" 2>/dev/null)
  fi
  code=$(printf '%s' "$out" | tail -1)
  body=$(printf '%s' "$out" | sed '$d')
  if [ "$code" = 200 ]; then
    local name
    name=$(printf '%s' "$body" | sed -n 's/^data: //p' | "$PY" -c '
import json, sys
d = json.load(sys.stdin)["result"]["content"][0]["text"]
print(json.loads(d)["과제명"])' 2>/dev/null)
    printf 'ok\t✔ %s' "${name:-응답 있음}"
  else
    local msg
    msg=$(printf '%s' "$body" | "$PY" -c 'import json,sys; print(json.load(sys.stdin)["error"]["message"])' 2>/dev/null)
    msg=${msg#Bad Request: }
    printf 'no\t✘ %s (HTTP %s)' "${msg:-응답 없음}" "${code:-000}"
  fi
}

cell() {
  local v=$1 want=$2 st msg col
  st=${v%%$'\t'*}; msg=${v#*$'\t'}
  [ "$st" = ok ] && col=$GREEN || col=$RED
  printf '%s' "$col"; pad "$msg" "$want"; printf '%s' "$RST"
}

SID=$(open_session) || SID=""
a1=$(ask "$OLD_PORT");        b1=$(ask "$NEW_PORT")
a2=$(ask "$OLD_PORT" "$SID"); b2=$(ask "$NEW_PORT" "$SID")

printf '  %s보낸 요청%s  get_project("2026-AI-013"). 4번 다 같은 요청이고 세션 헤더만 다릅니다\n\n' \
  "$DIM" "$RST"

row() {  # row <색> <스펙 라벨> <포트> <헤더 설명> <결과>
  printf '  %s' "$2"; pad "" 1
  printf '%s%s%s ' "$CYAN" ":$3" "$RST"
  pad "$4" 12
  cell "$5" 0
  printf '%s\n' "$RST"
}
printf '  %s구 스펙 2025-11-25%s\n' "${YEL}" "$RST"
row "$YEL" "$(pad '' 2)" "$OLD_PORT" "헤더 없이"   "$a1"
row "$YEL" "$(pad '' 2)" "$OLD_PORT" "헤더 붙여서" "$a2"
printf '\n  %s신 스펙 2026-07-28%s\n' "${GREEN}" "$RST"
row "$GREEN" "$(pad '' 2)" "$NEW_PORT" "헤더 없이"   "$b1"
row "$GREEN" "$(pad '' 2)" "$NEW_PORT" "헤더 붙여서" "$b2"

printf '\n  %s즉 구 스펙은 세션 헤더가 없다면 진행되지 않습니다. 그래서 4번 중에 1번만 안 된 것입니다.%s\n' \
  "$CYAN" "$RST"
