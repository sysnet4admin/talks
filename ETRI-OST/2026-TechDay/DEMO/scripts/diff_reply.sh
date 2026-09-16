#!/usr/bin/env bash
# 같은 요청에 대한 두 응답을 나란히 놓고 다른 곳만 확인한다.
#
# 2단계 후반이다. 신 스펙 응답만 전부 보여 주면 구 스펙과 무엇이 다른지 알 수
# 없다. 헤더와 본문을 각각 비교하면 다른 곳이 한 줄뿐이라는 것이 보인다.
set -uo pipefail
PY="${OST_PY:-$HOME/.cache/ost-demo/venv/bin/python}"
OLD_PORT="${OST_OLD_PORT:-8100}"
NEW_PORT="${OST_NEW1_PORT:-8200}"

if { [ -t 1 ] || [ "${OST_COLOR:-0}" = "1" ]; } && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RST=$'\033[0m'
  GREEN=$'\033[32m'; YEL=$'\033[33m'; CYAN=$'\033[36m'
else BOLD=; DIM=; RST=; GREEN=; YEL=; CYAN=; fi

H='Content-Type: application/json'
A='Accept: application/json, text/event-stream'
META='"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientCapabilities":{}}'
BODY="{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{$META}}"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# 구 스펙은 세션을 열어야 답한다. 그 헤더를 붙여서 같은 요청을 보낸다.
SID=$(curl -s -D- -o /dev/null --max-time 3 -X POST "http://127.0.0.1:$OLD_PORT/mcp" -H "$H" -H "$A" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"ost-demo","version":"1"}}}' \
  2>/dev/null | awk -F': ' 'tolower($1)=="mcp-session-id"{gsub(/\r/,"",$2); print $2}')
curl -s -o /dev/null --max-time 3 -X POST "http://127.0.0.1:$OLD_PORT/mcp" -H "$H" -H "$A" \
  -H "mcp-session-id: $SID" -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' 2>/dev/null

curl -s -D "$TMP/old.h" -o "$TMP/old.b" --max-time 3 -X POST "http://127.0.0.1:$OLD_PORT/mcp" \
  -H "$H" -H "$A" -H "mcp-session-id: $SID" -d "$BODY" 2>/dev/null
curl -s -D "$TMP/new.h" -o "$TMP/new.b" --max-time 3 -X POST "http://127.0.0.1:$NEW_PORT/mcp" \
  -H "$H" -H "$A" -d "$BODY" 2>/dev/null

# date 는 매번 달라서 비교에서 뺀다. 프로토콜과 무관한 값이다.
strip() { tr -d '\r' < "$1" | grep -viE '^(date):' | grep -v '^$'; }
strip "$TMP/old.h" > "$TMP/old.hs"; strip "$TMP/new.h" > "$TMP/new.hs"

printf '  %s같은 tools/list 요청입니다. 구 스펙에만 세션 헤더를 붙였습니다.%s\n\n' "$DIM" "$RST"

printf '  %s응답 헤더%s\n' "$BOLD" "$RST"
# -U3 으로 앞뒤 세 줄을 같이 보인다. 다른 줄만 떼어 놓으면 어디가 달라졌는지
# 자리가 안 보인다. 머리말(---, +++, @@)은 화면에 필요 없어 걸러 낸다.
diff -U3 "$TMP/old.hs" "$TMP/new.hs" > "$TMP/d" 2>/dev/null
if [ -s "$TMP/d" ]; then
  while IFS= read -r line; do
    case "$line" in
      ---*|+++*|@@*) ;;
      '-'*) printf '    %s- %s%s   %s← 구 스펙에만%s\n' "$YEL"   "${line#-}" "$RST" "$YEL" "$RST" ;;
      '+'*) printf '    %s+ %s%s   %s← 신 스펙에만%s\n' "$GREEN" "${line#+}" "$RST" "$GREEN" "$RST" ;;
      *)    printf '    %s  %s%s\n' "$DIM" "${line# }" "$RST" ;;
    esac
  done < "$TMP/d"
else
  printf '    %s두 응답의 헤더가 같습니다%s\n' "$DIM" "$RST"
fi

printf '\n  %s응답 본문%s\n' "$BOLD" "$RST"
if diff -q "$TMP/old.b" "$TMP/new.b" >/dev/null 2>&1; then
  n=$(sed -n 's/^data: //p' "$TMP/new.b" | "$PY" -c '
import json, sys
t = json.load(sys.stdin)["result"]["tools"]
print("도구 %d개(%s), 설명과 입력 스키마까지" % (len(t), ", ".join(x["name"] for x in t)))
' 2>/dev/null)
  printf '    %s글자 하나까지 같습니다. %s%s\n\n' "$CYAN" "${n:-}" "$RST"
  # 같다고 말만 하면 무엇이 같은지 안 보인다. 양쪽이 받은 본문을 한 번 띄운다.
  sed -n 's/^data: //p' "$TMP/new.b" \
    | "$PY" -m json.tool --no-ensure-ascii --indent 2 2>/dev/null \
    | head -12 | sed "s/^/      ${DIM}/;s/\$/${RST}/"
  printf '      %s...%s\n' "$DIM" "$RST"
else
  printf '    %s다른 곳이 있습니다%s\n' "$YEL" "$RST"
  diff "$TMP/old.b" "$TMP/new.b" | head -10 | sed 's/^/    /'
fi
