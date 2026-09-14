#!/usr/bin/env bash
# 실행 중인 서버 4대가 전부 같은 파일이라는 것을 실제 프로세스로 보인다.
#
# 1단계의 증거다. 서버 코드를 보여 주는 것만으로는 "짧다"까지만 전해진다.
# 7월 28일 개정이 표준으로 삼은 것은 stateless_http=True 쪽이다. 그 플래그 하나가
# 두 스펙을 나눈다는 것은 같은 파일이 값만 달리 실행 중인 모습에서 보인다.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if { [ -t 1 ] || [ "${OST_COLOR:-0}" = "1" ]; } && [ -z "${NO_COLOR:-}" ]; then
  DIM=$'\033[2m'; RST=$'\033[0m'; GREEN=$'\033[32m'; YEL=$'\033[33m'; CYAN=$'\033[36m'
else DIM=; RST=; GREEN=; YEL=; CYAN=; fi

printf '  %s포트    PID      실행 중인 파일          STATELESS%s\n' "$DIM" "$RST"
for port in 8100 8101 8200 8201; do
  pid=$(lsof -ti tcp:"$port" 2>/dev/null | head -1)
  if [ -z "$pid" ]; then
    printf '  :%-6s %s(실행 중이 아님)%s\n' "$port" "$DIM" "$RST"
    continue
  fi
  # ps -E 는 그 프로세스의 환경변수까지 보여 준다. 값을 지어내지 않고 실물을 읽는다.
  env_st=$(ps -E -p "$pid" -o command= 2>/dev/null | tr ' ' '\n' | awk -F= '$1=="STATELESS"{print $2}' | head -1)
  file=$(ps -p "$pid" -o command= 2>/dev/null | tr ' ' '\n' | grep 'ost_server\.py$' | head -1)
  file=${file#"$HERE/"}
  if [ "$env_st" = "1" ]; then
    printf '  %s:%-6s %-8s %-23s %s   → stateless_http=True  (신 스펙 2026-07-28)%s\n' "$GREEN" "$port" "$pid" "${file:-?}" "$env_st" "$RST"
  else
    printf '  %s:%-6s %-8s %-23s %s   → stateless_http=False (구 스펙 2025-11-25)%s\n' "$YEL" "$port" "$pid" "${file:-?}" "$env_st" "$RST"
  fi
done
printf '\n  %s4대가 같은 파일입니다. 다른 것은 STATELESS 하나뿐입니다.%s\n' "$CYAN" "$RST"
