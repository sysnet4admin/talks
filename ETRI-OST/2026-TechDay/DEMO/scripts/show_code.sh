#!/usr/bin/env bash
# 서버 코드를 화면에 보이면서 7월 28일 개정과 관련된 줄만 강조한다.
#
# grep --color 에 기대지 않는다. 이 머신의 grep 은 ugrep 이라 GREP_COLORS 가
# 안 먹었다. 무대 장비에 무엇이 깔려 있을지도 모른다. awk 는 어디에나 같다.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# 화면에 보이는 명령과 실제 실행이 같아야 한다. 인자는 줄 번호가 아니라 이름으로
# 받는다. 화면에 "12 32" 가 뜨면 청중에게는 아무 뜻이 없다.
FILE="${OST_SRC:-$HERE/server/ost_server.py}"
PART="${1:-전체}"

# 줄 번호를 박아 두면 파일이 바뀔 때마다 어긋난다. 실제로 3번 어긋났고 그때마다
# 화면에서 stateless_http 줄이 잘렸다. 코드 안의 표식을 찾아 그 자리에서 센다.
_at() { grep -n -m1 -- "$1" "$FILE" | cut -d: -f1; }
EOFL=$(wc -l < "$FILE" | tr -d ' ')
MAIN=$(_at 'if __name__')

case "$PART" in
  서버)  FROM=$(_at '^from mcp\.server'); TO=$(awk 'NR>'"$(_at '^PROJECTS = {')"' && /^}/ {print NR; exit}' "$FILE") ;;
  도구)  FROM=$(_at '^# 데코레이터');      TO=$((MAIN - 1)) ;;
  실행)  FROM=$MAIN;                        TO=$EOFL ;;
  전체)  FROM=$(_at '^from mcp\.server');  TO=$EOFL ;;
  *) echo "쓰는 법: $(basename "$0") [서버|도구|실행|전체]" >&2; exit 2 ;;
esac

# 1.demo.sh 는 출력을 파이프로 받으므로 tty 검사만으로는 색이 꺼진다.
# 러너가 OST_COLOR=1 을 넘겨 주면 켠다.
# 색은 데모 전체에서 한 가지 뜻으로만 쓴다. 노랑은 구 스펙을 가리키고 초록은 신 스펙을
# 가리킨다(show_servers.sh, list_both.sh, watch_calls.sh 와 같다). 중요하다는 뜻으로
# 노랑을 쓰면 같은 단계 안에서 노랑이 두 가지를 가리키게 된다.
# 자주는 도구 정의를 가리킨다. 이 파일에만 쓰고 다른 뜻으로 쓰지 않는다.
# 청록은 MCP 서버 본체를 만들고 실행하는 줄이다. 만드는 줄에만 색이 없으면 화면에서
# "서버를 만드는 줄은 1줄입니다" 라고 짚을 곳이 안 보인다.
if { [ -t 1 ] || [ "${OST_COLOR:-0}" = "1" ]; } && [ -z "${NO_COLOR:-}" ]; then
  OLDC=$'\033[1;33m'; NEWC=$'\033[1;32m'; KEY=$'\033[1;36m'
  TOOL=$'\033[1;35m'; DIM=$'\033[2m'; RST=$'\033[0m'
else OLDC=; NEWC=; KEY=; TOOL=; DIM=; RST=; fi

# 가짜 과제 데이터 열몇 줄은 접는다. 화면이 길어지면 맨 아래 stateless_http 줄이
# 밀려 나가는데, 그 줄이 이 단계의 핵심이다. 데이터는 무엇이 들었는지만 보이면 된다.
# 구간 끝의 빈 줄은 떨어뜨린다. 도구 구간은 __main__ 앞 빈 줄 2개로 끝난다.
sed -n "${FROM},${TO}p" "$FILE" \
  | awk 'BEGIN{n=0} {b[n++]=$0} END{while(n>0 && b[n-1]=="") n--; for(i=0;i<n;i++) print b[i]}' \
  | awk -v oldc="$OLDC" -v newc="$NEWC" -v key="$KEY" -v tool="$TOOL" -v rst="$RST" -v dim="$DIM" '
      /^PROJECTS = \{/ { print; fold = 1; next }
      fold && /^\}/    { print dim "    ... 연구과제 2건 (과제명, 수행기관, 기간, 단계)" rst; print; fold = 0; next }
      fold             { next }
      /^@mcp\.tool\(\)/       { print tool $0 rst; next }
      /^def (get|update)_project/ { print tool $0 rst; next }
      /stateless_http=False/ { print oldc $0 rst; next }
      /stateless_http=True/  { print newc $0 rst; next }
      /^mcp = MCPServer\(/  { print key  $0 rst; next }
      /mcp\.run\(/          { print key  $0 rst; next }
      { print }
    '
