#!/usr/bin/env bash
# OST 2026 라이브 데모 러너. 치트시트가 아니라 실제 실행기다.
# 각 단계는 명령을 먼저 보여 준 뒤 엔터를 기다렸다가 실제로 실행한다.
# 발표자가 속도를 쥐고 청중은 실제 출력을 본다. (KubeCon Japan 2026 러너와 같은 방식)
#
# set -e 는 일부러 끈다. 한 단계가 어긋나도 데모 전체가 멈추면 안 된다.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
URL="${MCP_URL:-http://127.0.0.1:8200/mcp}"
PY="${OST_PY:-/tmp/ostvenv/bin/python}"
MODEL="${OST_MODEL:-ost-demo}"
BASE_MODEL="${OST_BASE_MODEL:-gemma4:e2b-it-qat}"   # 4단계 화면에서 이름을 밝힌다
# 4단계에서 2번 쓰는 질문. 한 곳에서 관리해야 두 명령이 정말 같다.
ASK="${OST_ASK:-2026-AI-013 과제가 뭐 하는 건지 한 줄로 알려줘}"   # 온도 0 파생 모델. 0.setup_before.sh 가 만든다
# 4단계 끝의 쓰기. 도구 이름도 인자 이름도 넣지 않는다. 에이전트가 고르는 것을 본다.
NEWSTAGE="${OST_NEWSTAGE:-4차년도 착수}"
ASKW="${OST_ASKW:-2025-OSS-041 과제를 ${NEWSTAGE}로 바꿔줘}"
# goose 배너에 작업 디렉토리가 그대로 찍힌다. 저장소 경로에는 사용자 이름이 들어가므로
# 무대에서는 중립 디렉토리에서 실행한다. --no-profile 이라 파일 도구가 없어서 어디서
# 돌아도 결과는 같다.
GDIR="${OST_GDIR:-/tmp/ost-demo}"

# 서버가 실행 중이 아니면 준비가 덜 된 상태로 시작하지 않는다.
# GET은 스트림을 잡고 있어 타임아웃이 정상이므로, 상태 코드가 왔는지로만 본다.
_code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "$URL" 2>/dev/null)
if [ "${_code:-000}" = "000" ]; then
  echo "✗ 서버가 응답하지 않습니다 ($URL). 먼저: ./0.setup_before.sh" >&2
  exit 1
fi

# 모델이 내려가 있으면 무대에서 첫 호출이 3.5초가 아니라 10~11초가 된다.
if ! ollama ps 2>/dev/null | grep -q "$MODEL"; then
  echo "⚠ 모델 $MODEL 이 메모리에 없습니다. 첫 호출이 10초 넘게 걸립니다." >&2
  echo "  먼저: ./0.setup_before.sh  (워밍까지 다시 합니다)" >&2
fi

# 헬퍼 스크립트는 _emit 의 파이프로 출력하므로 자기 tty 검사가 실패한다.
# 러너 화면이 tty 면 헬퍼에도 색을 켜라고 알린다.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then export OST_COLOR=1; fi
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RST=$'\033[0m'
  CYAN=$'\033[36m'; GREEN=$'\033[32m'; YEL=$'\033[33m'; RED=$'\033[31m'; INV=$'\033[7m'
else
  BOLD=; DIM=; RST=; CYAN=; GREEN=; YEL=; RED=; INV=
fi

# step "제목" "이 단계에 쓸 시간".
# 시간은 화면에 안 찍는다. 발표자가 속도를 잡는 값이지 청중이 알 것이 아니고,
# 화면에 있으면 "45초 만에 끝난다" 로 읽혀 시계를 보게 된다.
# note 와 같은 경로로 나가므로 OST_NOTES=1 이나 프롬프터에서만 보인다.
#
# 값은 2026-08-31 m2 실측이다. 그 뒤 1단계가 엔터 1곳에서 4곳으로 늘었으므로
# 45초는 지금 구성과 맞지 않는다. m2 재측정 때 네 값을 다시 잡는다.
step() {
  printf '\n%s %s %s\n' "${INV}${BOLD}${YEL}" "$1" "${RST}"
  note "이 단계에 쓸 시간은 $2입니다."
}
# 발표자 전용 문구. 화면은 청중이 같이 본다. 기본은 화면에 내보내지 않는다.
#   OST_NOTES=1        리허설. 화면에 같이 찍는다
#   OST_PROMPTER=<파일> 다른 화면에서 tail -f 로 본다
#   기본값             감춘다
note() {
  [ -n "${OST_PROMPTER:-}" ] && printf '%s\n' "$1" >> "$OST_PROMPTER"
  [ "${OST_NOTES:-0}" = "1" ] && printf '  %s%s%s\n' "${DIM}" "$1" "${RST}"
  return 0
}
# OST_HL 이 있으면 그 값을 굵게 낸다. 지금 보는 값이 어디 있는지 짚는 용도다.
# read_stage.sh 가 단계 값을 굵게 내는 것과 같은 뜻이라 화면에서 짝이 맞는다.
_hl() {
  local _l=$1
  [ -n "${OST_HL:-}" ] && _l=${_l//"$OST_HL"/${BOLD}${OST_HL}${RST}}
  printf '%s' "$_l"
}
# 실행한 뒤 출력을 │ 블록으로 감싸고 실제 걸린 시간을 아래에 찍는다.
_emit() {
  printf '\n'
  local _t0 _el
  _t0=$(date +%s.%N)
  eval "$1" 2>&1 | while IFS= read -r _line; do
    printf '  %s│%s %s\n' "${DIM}" "${RST}" "$(_hl "$_line")"
  done
  _el=$(echo "$(date +%s.%N) - $_t0" | bc 2>/dev/null)
  printf '  %s└ %.1f초%s\n' "${DIM}" "${_el:-0}" "${RST}"
}
# _emit_retry "<실행할 것>" "<표시1>" "<표시2>"... : 표시가 다 있어야 성공. 없으면 한 번 더.
# 2026-08-31 m2 실측 기준으로 두 가지가 어긋난다.
#   - 46회 중 1회: 도구를 아예 안 부른다(▸ 줄이 없다). 답은 그럴듯해서 화면으로는 모른다
#   - 15회 중 2회: 도구는 불렀는데 답이 엉뚱하거나 출력 한도에 걸려 잘린다
# 그래서 도구 줄과 과제명을 둘 다 본다. 사람이 무대에서 판단할 일이 아니다.
# 기본 3회까지 다시 한다(OST_TRIES 로 바꾼다). 한 번이 7~8초라 부담이 낮다.
_emit_retry() {
  local _cmd="$1"; shift
  local _need=("$@") _try _tmp _t0 _el _ok _m
  local _max=${OST_TRIES:-3}
  for _try in $(seq 1 "$_max"); do
    _tmp=$(mktemp)
    printf '\n'
    _t0=$(date +%s.%N)
    eval "$_cmd" 2>&1 | tee "$_tmp" | while IFS= read -r _line; do
      printf '  %s│%s %s\n' "${DIM}" "${RST}" "$(_hl "$_line")"
    done
    _el=$(echo "$(date +%s.%N) - $_t0" | bc 2>/dev/null)
    printf '  %s└ %.1f초%s\n' "${DIM}" "${_el:-0}" "${RST}"
    _ok=1
    for _m in "${_need[@]}"; do
      [ "$(grep -c -- "$_m" "$_tmp" 2>/dev/null)" -ge 1 ] || _ok=0
    done
    rm -f "$_tmp"
    if [ "$_ok" -eq 1 ]; then
      [ "$_try" -gt 1 ] && printf '  %s✓ %d번째에 성공했습니다%s\n' "${GREEN}" "$_try" "${RST}"
      return 0
    fi
    if [ "$_try" -lt "$_max" ]; then
      printf '\n  %s⟳ 도구 호출이나 응답이 완전하지 않습니다. 한 번 더 실행합니다 (%d/%d).%s\n' \
        "${BOLD}${YEL}" "$_try" "$_max" "${RST}"
      note '말: "모델이 작아 결과가 일정하지 않습니다. 한 번 더 실행하겠습니다."'
    fi
  done
  printf '\n  %s✗ %d번 모두 실패했습니다. 화면의 ▸ 줄만 확인하고 넘어가거나 백업 녹화를 사용합니다.%s\n' \
    "${BOLD}${RED}" "$_max" "${RST}"
  return 1
}

# show_cmd "<한국어 설명>" "<화면에 보일 명령>" ["<엔터 안내 문구>"]
#   ▶ 줄은 무엇을 하는지, 그 아래 $ 줄은 실제로 실행되는 명령이다.
#
#   **4단계의 goose 3곳에만 쓴다**. 그 3곳은 명령 자체가
#   증거다. 옵션 하나가 붙고 안 붙고로 답이 달라지므로 청중이 명령을 읽어야 한다.
#   나머지 칸은 헬퍼 스크립트라 경로를 보여 봐야 읽을 것이 없다. 그런 자리에는
#   run 을 쓰고 ▶ 설명만 낸다.
#
#   보일 명령에 줄바꿈이 있으면 이어지는 줄은 들여쓴다. goose 명령이 140칸이라
#   한 줄에 안 들어간다.
show_cmd() {
  printf '\n  %s▶%s %s\n' "${BOLD}${GREEN}" "${RST}" "$1"
  printf '%s\n' "$2" | { _first=1
    while IFS= read -r _l; do
      if [ "$_first" = 1 ]; then printf '    %s$%s %s\n' "${DIM}" "${RST}" "$_l"; _first=0
      else printf '      %s\n' "$_l"; fi
    done; }
  printf '    %s↵ %s%s ' "${DIM}" "${3:-엔터를 누르면 실행됩니다}" "${RST}"
  IFS= read -r _
}
# run "<한국어 설명>" "<실행할 것>" : 설명만 보이고 엔터를 기다렸다가 실행한다.
run() {
  printf '\n  %s▶%s %s\n' "${BOLD}${GREEN}" "${RST}" "$1"
  printf '    %s↵ 엔터를 누르면 실행됩니다%s ' "${DIM}" "${RST}"
  IFS= read -r _
  _emit "$2"
}
# 청중이 봐도 되는 짧은 안내를 찍고 멈춘다. 어디를 보라는 안내는 화면에 나와야
# 발표자도 지금이 어디쯤인지 안다. 대사는 beat 가 맡고 이쪽은 위치 표시만 한다.
cue() {
  # 인자를 여러 개 주면 줄을 나눠 찍는다. 한글은 두 칸이라 한 줄이 금세 넘친다.
  printf '\n'
  local _l
  for _l in "$@"; do printf '  %s%s%s\n' "${DIM}" "$_l" "${RST}"; done
  # 문구 없이 ↵ 만 찍으면 방금 누른 실행용 엔터를 또 누르는 것처럼 보인다
  #. 이 엔터가 무엇을 하는지 적어 실행용과 가른다.
  printf '    %s↵ 다음으로 넘어갑니다%s ' "${DIM}" "${RST}"
  IFS= read -r _
}
# 실행 없이 넘긴다. 말로 설명하는 대목이라 문구는 발표자 전용이다.
beat() {
  note "$1"
  printf '\n    %s↵ 다음으로 넘어갑니다%s ' "${DIM}" "${RST}"
  IFS= read -r _
}

printf '%s=== MCP 데모 (엔터로 한 단계씩) ===%s\n' "${BOLD}${YEL}" "${RST}"
note "데모 전체 예산은 4분 15초입니다. 단계마다 쓸 시간은 그 단계 머리에 나옵니다."
note "서버는 이미 실행 중입니다. 만드는 과정은 코드로 확인하고 연결과 호출은 직접 실행합니다."
note "왼쪽 터미널에서 ./watch_calls.sh 가 돌고 있어야 3단계가 됩니다."

# ── 1. 서버는 몇 줄인가 ────────────────────────────────────────────────
step "[1/4] 서버 코드를 봅니다" "45초"
# 한 번에 다 찍으면 76줄이 스크롤로 지나가고 설명할 자리가 없다. 세 덩이로 끊어
# 엔터마다 이어 붙인다. 덩이마다 그때 볼 곳을 cue 로 짚는다.
note "도구 2개짜리 MCP 서버입니다. 코드를 세 번에 나눠 보고 그다음 지금 실행 중인 4대를 봅니다."
run "ost_server.py 앞부분: 서버를 만들고 데이터를 둡니다" \
    "'$HERE/scripts/show_code.sh' 서버"
note "세션을 만드는 코드도, 지우는 코드도 없습니다. 구 스펙에서는 이 자리에 세션 저장소가 있었습니다."
cue "← 서버를 만드는 줄은 1줄입니다. 나머지는 도구가 조회할 데이터입니다"
run "이어서 도구 2개" \
    "'$HERE/scripts/show_code.sh' 도구"
cue "← 자주색으로 표시한 것이 도구 2개입니다." \
    "  조회하는 get_project 와 값을 바꾸는 update_project 입니다." \
    "  바로 아래 설명글과 타입이 그대로 도구 설명이 됩니다. 스키마를 따로 쓰지 않습니다."
run "이어서 서버를 실행하는 곳" \
    "'$HERE/scripts/show_code.sh' 실행"
note "이 플래그는 구 계열 SDK(mcp 1.x)에도 있었습니다. 기본값이 False 였을 뿐입니다."
note "2026-07-28 개정이 한 일은 이쪽을 표준으로 삼은 것입니다. 세션과 핸드셰이크가 스펙에서 빠졌습니다."
cue "← 노랑은 구 스펙이고 초록은 신 스펙입니다." \
    "  세션 없이 도는 쪽이 2026-07-28 개정으로 표준이 됐습니다."
run "지금 실행 중인 서버 4대" \
    "'$HERE/scripts/show_servers.sh'"
beat "4대가 같은 파일입니다. 8100번과 8101번만 그 플래그가 0 입니다. 양쪽이 2대씩이라 서버 수는 같습니다."

# ── 2. 핸드셰이크 없이 바로 묻는다 ────────────────────────────────────
# "세션 헤더가 없다"는 요청 쪽 사실이라 응답만 봐서는 알 수 없다. 같은 요청을
# 구 스펙에도 보내야 증거가 된다. 한쪽은 400, 한쪽은 200 이 온다.
step "[2/4] 세션 헤더에 따라 동작이 달라지는지 봅니다" "30초"
note "구 스펙에서는 initialize 핸드셰이크를 먼저 하고 Mcp-Session-Id를 받아야 했습니다."
note "신 스펙은 요청 안의 _meta 필드가 프로토콜 버전과 기능 목록을 가지고 있습니다."
run "같은 도구를 4번 호출합니다. 세션 헤더만 다릅니다" \
    "'$HERE/scripts/list_both.sh'"
cue "← 과제명이 뜨면 진행된 것입니다. 4번 중에 1번만 안 됩니다"
note "구 스펙은 헤더가 없으면 요청을 읽어 보지도 않고 거절합니다. 세션부터 열라는 뜻입니다."
note "신 스펙은 헤더가 있어도 무시하고 그대로 진행합니다."
note "그래서 구 스펙 클라이언트는 신 스펙 서버에 붙지만 반대는 안 됩니다. 이것이 호환 규칙입니다."
run "두 응답을 나란히 놓고 다른 곳만 봅니다" \
    "'$HERE/scripts/diff_reply.sh'"
note "다른 곳은 헤더 한 줄뿐입니다. 구 스펙은 세션 ID를 돌려주고 신 스펙은 돌려줄 세션이 없습니다."
beat "본문은 글자 하나까지 같습니다. 도구 설명도 입력 스키마도 그대로입니다. 바뀐 것은 세션 하나입니다."

# ── 3. 서버를 죽인다 ──────────────────────────────────────────────────
# 왼쪽 터미널에서 watch_calls.sh 가 돌고 있어야 한다. 두 쪽에 같은 호출을 계속
# 보내는 화면이다. 이 단계의 증거가 거기서 나온다.
step "[3/4] 서버를 죽입니다" "1분"
for _p in 8100 8101 8200 8201; do
  [ -z "$(lsof -ti tcp:$_p 2>/dev/null)" ] && \
    printf '  %s✗%s :%s 가 없습니다. 먼저: ./0.setup_before.sh\n' "${RED:-}" "${RST}" "$_p"
done
note "왼쪽 화면을 봅니다. 양쪽 다 2대씩이고 클라이언트도 같습니다. 실패하면 다른 대로 넘깁니다."
note "같은 호출을 계속 보내고 있고 지금은 양쪽 다 초록입니다."
run "양쪽에서 1대씩 죽입니다 (8100번과 8200번)" \
    "for p in 8100 8200; do \
       pid=\$(lsof -ti tcp:\$p 2>/dev/null); \
       [ -n \"\$pid\" ] && { kill \$pid; echo \"kill :\$p (pid \$pid)\"; }; \
     done"
note "구 스펙은 8101번이 멀쩡히 실행 중인데도 빨강입니다. 세션이 죽은 8100번 안에 있었습니다."
note "클라이언트는 아무것도 바꾸지 않았습니다. 스티키 세션도 없습니다."
cue "← 왼쪽 화면. 양쪽 다 예비가 1대씩 남았는데 구 스펙만 끊깁니다"
run "2대를 다시 실행합니다" \
    "PORT=8100 STATELESS=0 nohup \"\$PY\" '$HERE/server/ost_server.py' >/tmp/ost-8100.log 2>&1 & \
     PORT=8200 STATELESS=1 nohup \"\$PY\" '$HERE/server/ost_server.py' >/tmp/ost-8200.log 2>&1 & \
     sleep 3; for p in 8100 8200; do echo \"up :\$p (pid \$(lsof -ti tcp:\$p | tr '\\n' ' '))\"; done"
note "구 스펙을 보세요. 서버가 살아났는데도 Session not found 입니다. 신 스펙은 8200번이 알아서 돌아왔습니다."
note "세션이 죽은 프로세스 안에 있었습니다. 클라이언트가 initialize 부터 다시 해야 합니다. 2026-07-28 개정이 없앤 것이 이 절차입니다."
cue "← 왼쪽 화면. 구 스펙은 살아나도 Session not found, 신 스펙은 :8200 복귀"

# ── 4. MCP 를 붙이기 전과 후 ──────────────────────────────────────────
# 같은 명령을 두 번 실행한다. 두 번째만 --with-streamable-http-extension 이
# 붙는다. 명령이 같아야 답이 달라진 이유가 그 옵션 하나로 좁혀진다.
#
# --no-profile 이 있어야 한다. goose 는 기본으로 자기 파일 도구를 싣고 다녀서
# 그것 없이 물으면 작업 디렉토리를 뒤지다 22초까지 갔다(2026-09-14 m4 측정).
# 도구가 아예 없는 goose 와 서버 도구만 있는 goose 를 비교해야 정확하다.
#
# 이 단계가 보이는 것은 MCP 일반이지 2026-07-28 개정이 아니다. 7/28 과 관련된
# 곳은 mcp.json 에 세션 관리가 없다는 것 하나다. 발표자가 그 경계를 알고 말한다.
step "[4/4] MCP를 붙이기 전과 후를 봅니다" "2분 35초"
# "같은 모델" 이라고 말만 하면 청중은 확인할 길이 없다. 무엇이 떠 있는지 먼저 보인다
#. 외부 API 가 아니라 이 노트북 안이라는 것도 여기서 걸린다.
run "MCP를 붙일 로컬 모델" \
    "ollama ps"
# 화면에는 "온도 0" 이라고 쓰지 않는다. 그러면 온도가 무엇이냐는 질문이 먼저 나와서
# 4단계가 하려는 얘기에서 멀어진다. 방법은 아래 note 가 들고
# 있다가 질문이 오면 답한다.
#
# 다만 "같은 답이 나오도록 맞췄다" 고 쓰지 않는다. 데모가 되게 손본 것처럼 읽힌다
#. 온도 0 은 답을 심는 것이 아니라 뽑기를 끄는 것이므로
# 모델은 그대로이고 무작위성만 껐다고 쓴다.
cue "← 모델은 $BASE_MODEL 그대로입니다. 답을 고를 때 쓰는 무작위성만 껐습니다." \
    "  외부 API 를 부르지 않습니다. 응답은 이 노트북에서 실행되는 AI 모델이 해 줍니다." \
    "  이어서 할 질문 2번에 이 모델을 그대로 씁니다."
note "물으면: ollama 쪽에서 온도를 0으로 고정한 파생 모델입니다. 온도는 다음 낱말을 고를 때 얼마나 흔들릴지를 정합니다."
note "물으면: 기본값으로 두면 4회 중 2회 도구를 아예 안 불렀습니다. 0으로 고정하니 6회 다 불렀습니다."
note "$BASE_MODEL 은 4.6B 짜리입니다. 무대에서 답이 6~8초에 나오는 크기입니다."
note "같은 질문을 2번 합니다. 명령도 같습니다. 두 번째만 옵션이 하나 붙습니다."

# 질문을 흐리게 쓰지 않는다. 청중이 읽어야 하는 곳이고 2번 다 같은 질문이라는 것이
# 이 단계의 근거다. 두 명령의 다른 곳은 아래 청록 하나뿐이라
# 흐림으로 또 가릴 이유가 없다.
# 한 줄로 쓰면 붙인 뒤 명령이 140칸이 되어 무대에서 질문 중간이 잘린다. 질문을
# 둘째 줄로 내려 2번 다 같은 모양으로 둔다. 그러면 첫 줄만 견주면 된다.
show_cmd "MCP 없이 물어봅니다" \
  "goose run --no-profile \\
-t \"$ASK\""
_emit "cd '$GDIR' && GOOSE_PROVIDER=ollama GOOSE_MODEL=$MODEL goose run --no-session --no-profile -t '$ASK'"
# "학습 데이터에 없다" 고 쓰지 않는다. 확인할 수 없는 말이고, 정보가 없다는 쪽으로
# 끝나서 다음 칸으로 이어지지 않는다. 정보가 어디에 있는지 짚으면 그다음에 붙이는
# 이유가 선다.
cue "← 모델은 이 과제를 모릅니다. 이 정보는 사내 API 서버가 가지고 있습니다"
note "1단계에서 본 그 서버가 그 자리입니다. 실제로는 사내 API 나 DB 를 부르는 코드가 들어갑니다."
note "여러분의 연구과제 정보도 같습니다. 모델이 아니라 여러분 시스템에 있습니다."

note "이제 도구를 하나 붙입니다. 붙이는 비용은 설정 파일 1개입니다."
run "mcp.json 보기" \
    "cat '$HERE/client/mcp.json'"
cue "← url 한 줄이 전부입니다. 클라이언트에도 세션 관리가 없습니다"
note "구 스펙이었으면 여기에 세션을 열고 ID를 가지고 다니는 코드가 들어갔습니다."

show_cmd "MCP를 붙이고 같은 질문을 반복합니다" \
  "goose run --no-profile ${CYAN}--with-streamable-http-extension $URL${RST} \\
-t \"$ASK\"" \
  "같은 명령에 옵션 하나만 더했습니다 (어긋나면 최대 3회까지 자동 재시도)"
_emit_retry "cd '$GDIR' && GOOSE_PROVIDER=ollama GOOSE_MODEL=$MODEL goose run --no-session --no-profile --with-streamable-http-extension '$URL' -t '$ASK'" \
    "get_project" "에이전트 프로토콜"
cue "← 같은 모델을 사용해서 같은 질문을 했는데 다른 결과가 나왔습니다." \
    "  차이점이 있다면 MCP 서버를 붙였을 뿐입니다." \
    "  도구 2개 중에서 조회하는 쪽을 고르고 과제코드 자리까지 스스로 채웠습니다."
note "저는 도구 이름을 말하지 않았습니다. 과제 코드만 말했습니다."
note "화면의 과제코드: 2026-AI-013 을 보세요. 인자 이름도 제가 대지 않았습니다."
# 여기서 beat 를 한 번 더 쓰면 바로 위 cue 와 붙어 빈 ↵ 가 2번 뜬다. 무대에서는
# 화면에 아무것도 안 바뀐 채로 엔터만 2번 누르게 된다.
# 대사는 그대로 두고 멈춤만 없앤다. 위 cue 의 멈춤에서 같이 말한다.
note "어느 도구를 쓸지는 2단계에서 보신 그 설명과 입력 스키마를 읽고 에이전트가 정했습니다."

# ── 읽고 쓰고 다시 읽는다 ───────────────────────────────────────────
# 여기까지는 조회 1번뿐이라 검색해서 문맥에 넣는 것과 모양이 같다. 값을 바꾸는 일은
# 검색이 못 한다. 그래서 쓰기를 실제로 돌리고 남았는지까지 본다.
# 세 칸이 나란히 서야 바뀐 것이 보이므로 쓰기 전 값을 먼저 낸다.
note "여기까지는 조회뿐입니다. 조회만 되면 검색해서 붙여 주는 것과 다를 것이 없습니다."
run "바꾸기 전 값" \
    "'$HERE/scripts/read_stage.sh'"
cue "← 2025-OSS-041 은 지금 3차년도 착수입니다"

show_cmd "이번에는 MCP에 값을 바꿔 달라고 요청합니다" \
  "goose run --no-profile ${CYAN}--with-streamable-http-extension $URL${RST} \\
-t \"$ASKW\""
OST_HL="$NEWSTAGE" _emit_retry "cd '$GDIR' && GOOSE_PROVIDER=ollama GOOSE_MODEL=$MODEL goose run --no-session --no-profile --with-streamable-http-extension '$URL' -t '$ASKW'" \
    "update_project" "4차년도"
cue "← 이번에는 도구 2개 중에서 값을 바꾸는 쪽을 골랐습니다." \
    "  과제코드 와 새단계 를 둘 다 채웠습니다. 저는 도구 이름도 인자 이름도 말하지 않았습니다."

run "서버에 남았는지 다시 읽습니다" \
    "'$HERE/scripts/read_stage.sh'"
cue "← 3차년도 착수가 4차년도 착수로 바뀌었습니다." \
    "  읽은 쪽은 에이전트가 아니라 curl 입니다. 서버 안의 값이 바뀐 것입니다."
note "물으면: 검색은 값을 바꾸지 못합니다. 읽고 쓰고 다시 읽는 이 세 칸은 검색으로 안 되는 일입니다."
note "물으면: 서버 4대가 각자 메모리에 데이터를 듭니다. :8201 에는 안 갑니다. 실제 서비스라면 여기서 DB를 갱신합니다."
note "여러분이 연구실 도구 하나를 서버로 만들면 이렇게 쓰입니다. 슬라이드 마지막에서 그 얘기를 합니다."

printf '\n%s=== 데모를 마칩니다. 슬라이드로 돌아갑니다 ===%s\n' "${BOLD}${GREEN}" "${RST}"
printf '%s정리: ./9.cleanup.sh   다시 준비: ./0.setup_before.sh%s\n\n' "${DIM}" "${RST}"
