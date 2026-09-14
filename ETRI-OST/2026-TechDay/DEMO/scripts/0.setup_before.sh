#!/usr/bin/env bash
# OST 2026 데모 전체 초기화. 리허설과 발표 당일 아침에 이것 하나만 실행한다.
#
# 없으면 만들고 있으면 건너뛴다(멱등). 무엇을 얼마나 기다려야 하는지 단계마다
# 예상 시간을 먼저 보여 준다. 시간은 2026-08-31 m2(MacBook Air M2, 24GB) 실측이다.
#
# set -e 는 일부러 끈다. 한 단계가 삐끗해도 나머지 준비는 계속되어야 한다.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="${OST_VENV:-/tmp/ostvenv}"
PY="$VENV/bin/python"
URL="${MCP_URL:-http://127.0.0.1:8200/mcp}"
BASE_MODEL="${OST_BASE_MODEL:-gemma4:e2b-it-qat}"
MODEL="${OST_MODEL:-ost-demo}"        # 온도 0 파생 모델. 답 길이가 일정해져 3배 빠르다
KEEP="${OST_KEEP_ALIVE:-30m}"         # ollama 기본 5분이면 무대에서 모델이 내려간다

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RST=$'\033[0m'
  GREEN=$'\033[32m'; YEL=$'\033[33m'; RED=$'\033[31m'; INV=$'\033[7m'
else
  BOLD=; DIM=; RST=; GREEN=; YEL=; RED=; INV=
fi

FAIL=0
# step "[n/8] 제목" "예상 시간"
step() { printf '\n%s %s %s %s(%s)%s\n' "${INV}${BOLD}${YEL}" "$1" "${RST}" "${DIM}" "$2" "${RST}"; }
ok()   { printf '  %s✓%s %s\n' "${GREEN}" "${RST}" "$1"; }
work() { printf '  %s…%s %s\n' "${DIM}" "${RST}" "$1"; }
bad()  { printf '  %s✗%s %s\n' "${RED}" "${RST}" "$1"; FAIL=1; }
since() { printf '    %s└ %.1f초%s\n' "${DIM}" "$(echo "$(date +%s.%N) - $1" | bc)" "${RST}"; }

printf '%s=== OST 데모 초기화 ===%s\n' "${BOLD}${YEL}" "${RST}"
printf '%s전부 준비된 상태면 10초 안팎, 처음부터 시작하면 모델 내려받기까지 20분을 넘습니다.%s\n' \
  "${DIM}" "${RST}"

# ── 1. goose ──────────────────────────────────────────────────────────
step "[1/8] goose CLI" "설치돼 있으면 즉시 / 없으면 2~3분"
if command -v goose >/dev/null 2>&1; then
  ok "goose $(goose --version 2>&1 | tr -d ' ')"
else
  work "설치되어 있지 않아 설치합니다: brew install block-goose-cli"
  t=$(date +%s.%N); brew install block-goose-cli >/dev/null 2>&1; since "$t"
  command -v goose >/dev/null 2>&1 && ok "goose $(goose --version 2>&1 | tr -d ' ')" \
    || bad "goose 설치 실패. 직접: brew install block-goose-cli"
fi

# ── 2. ollama 데몬 ────────────────────────────────────────────────────
step "[2/8] ollama 데몬" "즉시 ~ 3초"
if pgrep -x ollama >/dev/null; then
  ok "이미 실행 중"
else
  work "실행합니다"
  nohup ollama serve >/tmp/ollama.log 2>&1 &
  for _ in $(seq 1 20); do ollama list >/dev/null 2>&1 && break; sleep 0.5; done
  pgrep -x ollama >/dev/null && ok "실행 완료" || bad "실행 실패. /tmp/ollama.log 확인"
fi

# ── 3. 베이스 모델 ────────────────────────────────────────────────────
step "[3/8] 베이스 모델 $BASE_MODEL" "있으면 즉시 / 없으면 15~20분 (4.3GB)"
has_model() { [ "$(ollama list 2>/dev/null | grep -cE "^$1([[:space:]]|:latest)" 2>/dev/null)" -gt 0 ]; }
if has_model "$BASE_MODEL"; then
  ok "이미 있음"
else
  work "내려받습니다. 네트워크 속도에 따라 오래 걸립니다"
  t=$(date +%s.%N); ollama pull "$BASE_MODEL"; since "$t"
  has_model "$BASE_MODEL" && ok "내려받기 완료" || bad "내려받기 실패"
fi

# ── 4. 온도 0 파생 모델 ───────────────────────────────────────────────
step "[4/8] 온도 0 파생 모델 $MODEL" "1초 (레이어 공유, 디스크 안 늘어남)"
if has_model "$MODEL"; then
  ok "이미 있음"
else
  work "만듭니다. 온도를 0으로 고정하면 응답 길이가 일정해집니다"
  printf 'FROM %s\nPARAMETER temperature 0\n' "$BASE_MODEL" > /tmp/Modelfile.ost
  ollama create "$MODEL" -f /tmp/Modelfile.ost >/dev/null 2>&1 \
    && ok "생성 완료" || bad "생성 실패"
fi

# ── 5. venv 와 mcp SDK ────────────────────────────────────────────────
# /tmp 는 재부팅으로 사라진다. agentgateway 측정에서 이것 때문에 한 시간을 날렸다.
step "[5/8] venv 와 mcp SDK" "있으면 즉시 / 없으면 2분 30초"
if "$PY" -c "import mcp" 2>/dev/null; then
  ok "mcp $("$PY" -c 'import importlib.metadata as m; print(m.version("mcp"))' 2>/dev/null)"
else
  work "$VENV 를 새로 만듭니다 (/tmp 는 재부팅으로 사라집니다)"
  t=$(date +%s.%N)
  { /opt/homebrew/bin/python3.13 -m venv "$VENV" 2>/dev/null || python3 -m venv "$VENV"; } \
    && "$VENV/bin/pip" -q install --upgrade pip && "$VENV/bin/pip" -q install "mcp>=2.0"
  since "$t"
  "$PY" -c "import mcp" 2>/dev/null \
    && ok "mcp $("$PY" -c 'import importlib.metadata as m; print(m.version("mcp"))' 2>/dev/null)" \
    || bad "mcp SDK 설치 실패. 네트워크 확인"
fi

# goose 배너에 작업 디렉토리가 찍힌다. 저장소 경로에는 사용자 이름이 들어가므로
# 무대에서는 여기서 실행한다. --no-profile 이라 파일 도구가 없어 결과는 같다.
mkdir -p "${OST_GDIR:-/tmp/ost-demo}"

# ── 6. 데모 서버 ──────────────────────────────────────────────────────
# 4대를 실행한다. 8100·8101 은 구 스펙(세션), 8200·8201 은 신 스펙(스테이트리스).
# 81xx 와 82xx 로 나눈 것은 SDK 가 1.x 와 2.x 로 나누어져서다. 화면에서 두 열이
# 나란히 서고 어느 쪽이 어느 쪽인지 숫자만 보고도 읽힌다.
# 양쪽을 2대씩 두어야 서버 수가 아니라 스펙 차이를 보게 된다.
# 3단계에서 8100 과 8200 을 죽여 두 쪽의 차이를 화면에 보인다.
step "[6/8] 데모 서버 4대 실행" "5~10초"
pkill -f 'ost_server.py' 2>/dev/null && { work "실행 중이던 서버를 종료했습니다"; sleep 1; }
t=$(date +%s.%N)
PORT=8100 STATELESS=0 nohup "$PY" "$HERE/server/ost_server.py" > /tmp/ost-8100.log 2>&1 &
PORT=8101 STATELESS=0 nohup "$PY" "$HERE/server/ost_server.py" > /tmp/ost-8101.log 2>&1 &
PORT=8200 STATELESS=1 nohup "$PY" "$HERE/server/ost_server.py" > /tmp/ost-8200.log 2>&1 &
PORT=8201 STATELESS=1 nohup "$PY" "$HERE/server/ost_server.py" > /tmp/ost-8201.log 2>&1 &
for _p in 8100 8101 8200 8201; do
  for _ in $(seq 1 40); do
    [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 1 "http://127.0.0.1:$_p/mcp" 2>/dev/null)" != "000" ] && break
    sleep 0.5
  done
done
since "$t"
for _p in 8100 8101 8200 8201; do
  _c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "http://127.0.0.1:$_p/mcp" 2>/dev/null)
  # 구 스펙(8100)은 세션 없이 부르면 400 이 정상이다. 000 만 죽은 것이다.
  [ "$_c" != "000" ] && ok ":$_p 응답 (HTTP $_c)" || bad ":$_p 가 응답하지 않습니다. /tmp/ost-$_p.log 확인"
done

# ── 7. 세션 없이 tools/list ───────────────────────────────────────────
step "[7/8] 세션 헤더 없이 tools/list" "0.01초 미만"
_meta='{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientCapabilities":{}}'
resp=$(curl -s -X POST "$URL" -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{\"_meta\":$_meta}}" 2>/dev/null)
if [[ "$resp" == *'"name":"get_project"'* ]]; then
  ok "get_project 가 목록에 있습니다"
else
  bad "tools/list 가 이상합니다"; printf '  %s%s%s\n' "${DIM}" "$(printf '%s' "$resp" | tail -c 200)" "${RST}"
fi

# ── 8. 모델 워밍 ──────────────────────────────────────────────────────
# 이 단계를 빼면 무대에서 첫 호출이 10초를 넘는다.
step "[8/8] 모델 워밍 (keep_alive $KEEP)" "10초 안팎"
t=$(date +%s.%N)
curl -s http://localhost:11434/api/chat -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"stream\":false,\"keep_alive\":\"$KEEP\"}" >/dev/null 2>&1
since "$t"
until_col=$(ollama ps 2>/dev/null | awk -v m="$MODEL" '$1 ~ m {for(i=6;i<=NF;i++) printf "%s ", $i; print ""}')
if [ -n "$until_col" ]; then
  ok "적재됨. 유효시간: ${until_col}"
else
  bad "모델이 적재되지 않았습니다. ollama ps 로 직접 확인"
fi

# ── 결과 ──────────────────────────────────────────────────────────────
if [ "$FAIL" -eq 0 ]; then
  printf '\n%s 준비 완료 %s  왼쪽 터미널: %s./watch_calls.sh%s   오른쪽 터미널: %s./1.demo.sh%s\n' \
    "${INV}${BOLD}${GREEN}" "${RST}" "${BOLD}" "${RST}" "${BOLD}" "${RST}"
  printf '%s무대 직전에 이 스크립트를 한 번 더 실행하면 워밍이 갱신됩니다.%s\n\n' "${DIM}" "${RST}"
else
  printf '\n%s 준비 실패 %s  위의 ✗ 를 먼저 해결하세요.\n\n' "${INV}${BOLD}${RED}" "${RST}"
  exit 1
fi
