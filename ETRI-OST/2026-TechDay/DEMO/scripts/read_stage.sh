#!/usr/bin/env bash
# 과제 1건을 서버에서 직접 읽어 단계만 보인다. 4단계의 쓰기 앞뒤로 2번 부른다.
#
# 에이전트를 쓰지 않는 것이 요점이다. 쓰기를 시킨 그 에이전트가 자기가 바꾼 값을
# 자기가 읽으면 "모델이 기억하고 말한 것 아니냐" 는 여지가 남는다. curl 은 상관없는
# 다른 클라이언트라 서버 안의 값을 그대로 보여 준다. 2단계에서 쓴 요청과 같은 형태다.
set -uo pipefail
PORT="${OST_NEW1_PORT:-8200}"
CODE="${OST_WCODE:-2025-OSS-041}"

if { [ -t 1 ] || [ "${OST_COLOR:-0}" = "1" ]; } && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RST=$'\033[0m'; RED=$'\033[31m'
else BOLD=; DIM=; RST=; RED=; fi

META='"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientCapabilities":{}}'
BODY="{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"get_project\",\"arguments\":{\"과제코드\":\"$CODE\"},$META}}"

printf '\n  %scurl 로 :%s 에 get_project("%s") 을 보냅니다. 에이전트를 거치지 않습니다%s\n\n' \
  "${DIM}" "$PORT" "$CODE" "${RST}"

resp=$(curl -s --max-time 3 -X POST "http://127.0.0.1:$PORT/mcp" \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d "$BODY" 2>/dev/null | tr -d '\r' | sed -n 's/^data: //p' | head -1)

if [ -z "$resp" ]; then
  printf '  %s✗ :%s 가 응답하지 않습니다%s\n' "${RED}" "$PORT" "${RST}"
  exit 1
fi

# 서버가 준 JSON 을 그대로 낸다. 키와 값을 떼어 표로 만들면 보고서처럼 읽혀서
# 구조화된 응답을 받았다는 것이 안 보인다.
printf '%s' "$resp" | BOLD="$BOLD" RST="$RST" python3 -c '
import json, os, sys
b, r = os.environ["BOLD"], os.environ["RST"]
d = json.loads(json.load(sys.stdin)["result"]["content"][0]["text"])
if "error" in d:
    print("     " + d["error"]); sys.exit(1)
last = list(d)[-1]
print("     {")
for k, v in d.items():
    val = "\"" + v + "\""
    if k == "단계":
        val = b + val + r
    print("       \"" + k + "\": " + val + ("" if k == last else ","))
print("     }")
'
