#!/usr/bin/env bash
# 왼쪽 화면. 구 스펙과 신 스펙에 같은 호출을 계속 보내고 상태를 제자리에서 갱신한다.
#
# watch(1) 처럼 화면이 흐르지 않고 같은 자리에서 바뀐다. 다만 흐르는 기록을
# 완전히 없애면 "한 줄도 안 끊겼다"는 증거가 사라지므로 두 가지를 같이 둔다.
#   - 누적 횟수: 신 스펙 실패 0 이 이 데모의 결론이다
#   - 최근 기록 여덟 줄: 끊긴 자리가 눈에 남는다
#
#   구 스펙 :8100 :8101  세션을 만들어 요청 사이에 저장한다 (stateless_http=False)
#   신 스펙 :8200 :8201  아무것도 저장하지 않는다 (stateless_http=True)
#
# 사용법: ./watch_calls.sh        (Ctrl+C 로 종료)
set -uo pipefail

# 양쪽을 2대씩 둔다. 한쪽만 2대면 "2대가 1대보다 잘 버티는 건 당연하다" 가 되고
# 이 데모가 보이려는 것이 스테이트리스가 아니라 이중화가 된다.
OLD1_PORT="${OST_OLD1_PORT:-8100}"
OLD2_PORT="${OST_OLD2_PORT:-8101}"
NEW1_PORT="${OST_NEW1_PORT:-8200}"
NEW2_PORT="${OST_NEW2_PORT:-8201}"
OLD="http://127.0.0.1:$OLD1_PORT/mcp"
NEW1="http://127.0.0.1:$NEW1_PORT/mcp"
NEW2="http://127.0.0.1:$NEW2_PORT/mcp"
# 한 틱은 20~30ms 로 끝나고 죽은 서버는 즉시 거부된다(2026-09-11 m4 실측).
# 그래서 간격은 기술 제약이 아니라 부하와 읽는 속도로 정한다. 0.5초는 코어
# 하나의 27%, 1초는 15% 를 쓴다. 대부분 프로세스를 띄우는 비용이다.
# 1초로 두면 최근 여덟 줄이 8초를 덮어 죽였다 살리는 구간이 화면에 다 남는다.
GAP="${OST_GAP:-1.0}"
PY="${OST_PY:-$HOME/.cache/ost-demo/venv/bin/python}"
KEEP="${OST_KEEP:-8}"          # 최근 기록으로 남길 줄 수
CODE="2026-AI-013"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RST=$'\033[0m'
  GREEN=$'\033[32m'; RED=$'\033[31m'; YEL=$'\033[33m'; CYAN=$'\033[36m'
  # 화면을 지우면 그 순간 빈 화면이 보여 깜박인다. 지우지 않고 덮어쓴다.
  # CUP 으로 좌상단에 간 다음 줄마다 EL 로 남은 꼬리를 지운다. 아래쪽 잔상은
  # 마지막에 ED 로 지운다. 그리고 프레임 전체를 한 번에 쓴다.
  CUP=$'\033[H'; EL=$'\033[K'; ED=$'\033[J'; HIDE=$'\033[?25l'; SHOW=$'\033[?25h'
else
  BOLD=; DIM=; RST=; GREEN=; RED=; YEL=; CYAN=; CUP=; EL=; ED=; HIDE=; SHOW=
fi

H='Content-Type: application/json'
A='Accept: application/json, text/event-stream'
META='"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientCapabilities":{}}'
CALL="\"name\":\"get_project\",\"arguments\":{\"과제코드\":\"$CODE\"}"

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

# 포트가 살아 있는지만 본다. lsof 는 틱마다 프로세스를 띄워서 비싸다.
# bash 내장 /dev/tcp 는 프로세스를 만들지 않는다.
alive() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null && exec 3<&- 3>&-; }

# ── 구 스펙: 시작할 때 한 번 initialize 하고 세션 ID 를 들고 간다 ──────
open_session() {
  local sid
  sid=$(curl -s -D- -o /dev/null --max-time 2 -X POST "$OLD" -H "$H" -H "$A" \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"ost-demo","version":"1"}}}' \
    2>/dev/null | awk -F': ' 'tolower($1)=="mcp-session-id"{gsub(/\r/,"",$2); print $2}')
  [ -n "$sid" ] || return 1
  curl -s -o /dev/null --max-time 2 -X POST "$OLD" -H "$H" -H "$A" -H "mcp-session-id: $sid" \
    -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' 2>/dev/null
  printf '%s' "$sid"
}

# 구 스펙도 신 스펙과 같은 규칙으로 보낸다. 실패하면 다른 대로 넘긴다.
# 클라이언트 동작을 같게 맞춰야 서버 쪽 차이만 남는다.
# curl 이 재 준 왕복 시간을 같이 돌려준다. 실패해서 다른 대로 넘기면 2번 걸린
# 시간을 더한다. 화면에 밀리초가 뜨면 요청이 실제로 오간다는 것이 보인다.
call_old() {
  local first=$1 second=$2 r t1 t2
  r=$(curl -s -w '\n%{time_total}' --max-time 2 -X POST "http://127.0.0.1:$first/mcp" -H "$H" -H "$A" -H "mcp-session-id: $SID" \
      -d "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{$CALL}}" 2>/dev/null)
  t1=${r##*$'\n'}; r=${r%$'\n'*}
  if [[ "$r" == *"과제명"* ]]; then printf '%s\t%s\t%s' "$first" "$t1" "$r"; return; fi
  local r2
  r2=$(curl -s -w '\n%{time_total}' --max-time 2 -X POST "http://127.0.0.1:$second/mcp" -H "$H" -H "$A" -H "mcp-session-id: $SID" \
      -d "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{$CALL}}" 2>/dev/null)
  t2=${r2##*$'\n'}; r2=${r2%$'\n'*}
  printf '%s\t%s\t%s' "$second" "$(awk -v a="$t1" -v b="$t2" 'BEGIN{print a+b}')" "$r2"
}

# 세션이 없으므로 아무 대나 보낸다. 실패하면 다른 대로 보낸다. 로드밸런서가 하는 일이다.
call_new() {
  local first=$1 second=$2 r t1 t2 r2
  r=$(curl -s -w '\n%{time_total}' --max-time 2 -X POST "http://127.0.0.1:$first/mcp" -H "$H" -H "$A" \
      -d "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{$CALL,$META}}" 2>/dev/null)
  t1=${r##*$'\n'}; r=${r%$'\n'*}
  if [[ "$r" == *"과제명"* ]]; then printf '%s\t%s\t%s' "$first" "$t1" "$r"; return; fi
  r2=$(curl -s -w '\n%{time_total}' --max-time 2 -X POST "http://127.0.0.1:$second/mcp" -H "$H" -H "$A" \
      -d "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{$CALL,$META}}" 2>/dev/null)
  t2=${r2##*$'\n'}; r2=${r2%$'\n'*}
  printf '%s\t%s\t%s' "$second" "$(awk -v a="$t1" -v b="$t2" 'BEGIN{print a+b}')" "$r2"
}

# 응답에서 과제명을 꺼낸다. 코드가 아니라 실제로 받은 값이 떠야 진행된 것이 보인다.
payload() {
  printf '%s' "$1" | sed -n 's/^data: //p' | "$PY" -c '
import json, sys
try:
    d = json.load(sys.stdin)["result"]["content"][0]["text"]
    print(json.loads(d)["과제명"])
except Exception:
    print("")
' 2>/dev/null
}

verdict() {
  local r=$1
  if   [[ "$r" == *"과제명"* ]];             then printf 'ok\t✔ 과제 조회 성공'
  elif [[ "$r" == *"Session not found"* ]];  then printf 'no\t✘ Session not found'
  elif [[ "$r" == *"Missing session ID"* ]]; then printf 'no\t✘ Missing session ID'
  elif [[ -z "$r" ]];                        then printf 'no\t✘ 연결 안 됨'
  else printf 'no\t✘ 실패'; fi
}

paint() {
  local v=$1 want=$2 st msg col
  st=${v%%$'\t'*}; msg=${v#*$'\t'}
  [ "$st" = ok ] && col=$GREEN || col=$RED
  printf '%s' "$col"; pad "$msg" "$want"; printf '%s' "$RST"
}

# 색 코드는 폭이 0 인데 pad 는 글자로 세므로, 색은 따로 찍고 폭은 평문으로 맞춘다.
dot() {
  if alive "$1"; then printf '%s●%s' "$GREEN" "$RST"; else printf '%s○%s' "$RED" "$RST"; fi
  printf ' :%s' "$1"
}

SID=$(open_session) || SID="none"
OK_OLD=0; NG_OLD=0; OK_NEW=0; NG_NEW=0; FLIP=0; T0=$(date +%s)
RECENT=()
printf '%s' "$HIDE"
trap 'printf "%s\n%s중지했습니다.%s\n" "$SHOW" "$DIM" "$RST"; exit 0' INT TERM

while true; do
  # 구 스펙은 세션을 가진 대를 먼저 부른다. 신 스펙은 세션이 없으니 번갈아 부른다.
  o_raw=$(call_old "$OLD1_PORT" "$OLD2_PORT")
  if [ $((FLIP % 2)) -eq 0 ]; then n=$(call_new "$NEW1_PORT" "$NEW2_PORT")
  else n=$(call_new "$NEW2_PORT" "$NEW1_PORT"); fi
  FLIP=$((FLIP + 1))
  # read 는 개행에서 끊긴다. 응답 본문에 개행이 들어 있으므로 파라미터 확장으로 나눈다.
  o_port=${o_raw%%$'\t'*}; _rest=${o_raw#*$'\t'}
  o_ms=${_rest%%$'\t'*};   o=${_rest#*$'\t'}
  port=${n%%$'\t'*};       _rest=${n#*$'\t'}
  n_ms=${_rest%%$'\t'*};   body=${_rest#*$'\t'}
  vo=$(verdict "$o"); vn=$(verdict "$body")
  p_old=$(payload "$o"); p_new=$(payload "$body")
  [ "${vo%%$'\t'*}" = ok ] && OK_OLD=$((OK_OLD+1)) || NG_OLD=$((NG_OLD+1))
  [ "${vn%%$'\t'*}" = ok ] && OK_NEW=$((OK_NEW+1)) || NG_NEW=$((NG_NEW+1))

  if [ -n "$port" ]; then who=":$port"; else who="  ?  "; fi
  RECENT+=(":$o_port"$'\x1f'"$vo"$'\x1f'"$who"$'\x1f'"$vn")
  while [ "${#RECENT[@]}" -gt "$KEEP" ]; do RECENT=("${RECENT[@]:1}"); done

  el=$(( $(date +%s) - T0 ))
  frame=$(
    printf '  %sMCP 서버 상태%s   %s경과 %d:%02d%s%s\n' \
      "${BOLD}${YEL}" "$RST" "$DIM" $((el/60)) $((el%60)) "$RST" "$EL"
    printf '  %s보내는 요청%s  tools/call get_project("2026-AI-013")   %s%s초마다%s%s\n%s\n' \
      "$DIM" "$RST" "$DIM" "$GAP" "$RST" "$EL" "$EL"

    printf '  %s' "${BOLD}"; pad "구 스펙 2025-11-25 (세션)" 30
    printf '%s신 스펙 2026-07-28 (스테이트리스)%s%s\n' "${BOLD}" "$RST" "$EL"
    printf '  '; dot "$OLD1_PORT"; printf '  '; dot "$OLD2_PORT"; pad "" 15
    dot "$NEW1_PORT"; printf '  '; dot "$NEW2_PORT"; printf '%s\n' "$EL"
    printf '  %s──────────────────────────%s    %s──────────────────────────%s%s\n' \
      "$DIM" "$RST" "$DIM" "$RST" "$EL"

    printf '  %s%-6s%s' "$CYAN" ":$o_port" "$RST"; paint "$vo" 24
    printf '%s%-6s%s' "$CYAN" "$who" "$RST"; paint "$vn" 22
    printf '%s\n' "$EL"
    # 과제명이 길어 두 열에 안 들어간다. 한 줄씩 편다.
    printf '  %s받은 값%s  구 스펙  ' "$DIM" "$RST"
    if [ -n "$p_old" ]; then printf '%s%s%s' "$GREEN" "$p_old" "$RST"
    else printf '%s(없음)%s' "$RED" "$RST"; fi
    printf '%s\n' "$EL"
    printf '           신 스펙  '
    if [ -n "$p_new" ]; then printf '%s%s%s' "$GREEN" "$p_new" "$RST"
    else printf '%s(없음)%s' "$RED" "$RST"; fi
    printf '%s\n%s\n' "$EL" "$EL"

    printf '  %s성공%s %-6d  %s실패%s %s%-6d%s' "$DIM" "$RST" "$OK_OLD" "$DIM" "$RST" "$RED" "$NG_OLD" "$RST"
    printf '     %s성공%s %-6d  %s실패%s %s%-6d%s' "$DIM" "$RST" "$OK_NEW" "$DIM" "$RST" \
      "$([ "$NG_NEW" -eq 0 ] && printf '%s' "$GREEN" || printf '%s' "$RED")" "$NG_NEW" "$RST"
    # 구 스펙이 한 번이라도 끊긴 뒤에야 이 문구가 뜻을 가진다. 그 전에는 양쪽 다 0 이다.
    [ "$NG_NEW" -eq 0 ] && [ "$NG_OLD" -gt 0 ] && printf '  %s← 한 번도 안 끊김%s' "$GREEN" "$RST"
    printf '%s\n%s\n' "$EL" "$EL"

    printf '  %s최근%s%s\n' "$DIM" "$RST" "$EL"
    for line in "${RECENT[@]}"; do
      IFS=$'\x1f' read -r r_op r_o r_who r_n <<< "$line"
      printf '    %s%-6s%s' "$CYAN" "$r_op" "$RST"; paint "$r_o" 24
      printf '%s%-6s%s' "$CYAN" "$r_who" "$RST"; paint "$r_n" 22
      printf '%s\n' "$EL"
    done
  )
  # 프레임 전체를 한 번에 내보낸다. 나눠 쓰면 그리는 도중이 보여 깜박인다.
  printf '%s%s\n%s' "$CUP" "$frame" "$ED"
  sleep "$GAP"
done
