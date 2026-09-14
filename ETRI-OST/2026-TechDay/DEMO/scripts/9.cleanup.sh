#!/usr/bin/env bash
set -uo pipefail
pkill -f 'ost_server.py' 2>/dev/null && echo "서버 4대를 종료했습니다 (8100, 8101, 8200, 8201)" || echo "실행 중인 서버가 없습니다"
echo "왼쪽 터미널의 watch_calls.sh 는 Ctrl+C 로 종료합니다"
echo "다음 리허설: ./0.setup_before.sh"
