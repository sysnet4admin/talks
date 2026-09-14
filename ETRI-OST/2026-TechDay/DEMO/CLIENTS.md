# 이 MCP 서버를 각자의 클라이언트로 붙여 보기

발표에서는 goose로 보여 드렸습니다. **같은 서버를 다른 클라이언트도 그대로 씁니다.**
서버를 한 번 만들면 어떤 클라이언트든 그 도구를 쓴다는 것이 MCP의 요지이고, 이 문서가
그 실물입니다. 쓰시는 것으로 골라 따라 해 보세요.

셋 다 **설정 파일에 등록하지 않습니다.** 실행할 때만 서버를 알려주는 방식이라 환경이
더러워지지 않고, 끝나면 흔적이 남지 않습니다.

## 먼저 서버를 띄웁니다

```bash
cd demo/scripts
./0.setup_before.sh
```

`준비 완료` 가 나오면 `http://127.0.0.1:8200/mcp` 에서 도구 하나(`get_project`)가
기다리고 있습니다. 조회 가능한 코드는 `2026-AI-013` 과 `2025-OSS-041` 입니다.

## goose

MCP와 같은 AAIF 프로젝트입니다. 로컬 모델로 돌아 네트워크가 필요 없습니다.

```bash
brew install block-goose-cli
ollama pull gemma4:e2b-it-qat

# 온도 0 고정이 중요합니다. 안 하면 모델이 도구를 안 부르고 답만 지어내는 일이 생깁니다
# (레이어를 공유해 디스크는 안 늘어납니다)
printf 'FROM gemma4:e2b-it-qat\nPARAMETER temperature 0\n' > /tmp/Modelfile.ost
ollama create ost-demo -f /tmp/Modelfile.ost

export GOOSE_PROVIDER=ollama GOOSE_MODEL=ost-demo
goose run --no-session \
  --with-streamable-http-extension "http://127.0.0.1:8200/mcp" \
  -t "get_project(2026-AI-013) 결과만 한 줄로"
```

도구 호출이 화면에 그대로 표시됩니다.

```
  ▸ get_project 127_0_0_1_8200_mcp
    code: 2026-AI-013
```

## 클로드 코드

`client/mcp.json` 이 저장소에 이미 들어 있습니다.

```bash
claude --mcp-config client/mcp.json --strict-mcp-config \
  -p "ost-demo 서버의 get_project 도구로 과제 코드 2026-AI-013을 조회해서 과제명과 수행기관만 알려줘" \
  --allowedTools "mcp__ost-demo__get_project"
```

`--strict-mcp-config` 가 다른 MCP 서버를 전부 무시하므로 이 데모만 격리되어 돕니다.
대화형으로 보려면 `-p` 를 빼고 띄운 뒤 같은 문장을 입력하면 됩니다.

## 코덱스

```bash
codex exec -c 'mcp_servers.ost-demo.url="http://127.0.0.1:8200/mcp"' \
  --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox \
  "ost-demo MCP 서버의 get_project 도구로 과제 코드 2026-AI-013을 조회해서 과제명과 수행기관만 한국어로 알려줘"
```

`-c` 로 넘긴 값은 `~/.codex/config.toml` 에 저장되지 않습니다.

**승인 정책 주의.** `codex exec` 의 기본값은 `approval: never` 인데 이 상태에서 MCP 도구
호출은 `MCP tool call requires approval, but approval policy is never` 로 막힙니다.
`-s workspace-write` 나 `-a on-failure` 로는 풀리지 않았고 위 플래그를 붙여야 실제로
호출됐습니다. 대화형(`codex` 로 띄우고 입력)은 승인 창이 떠서 그 자리에서 허용할 수
있습니다.

## 도구를 진짜 불렀는지 확인하세요

**답이 맞아 보여도 도구를 부르지 않았을 수 있습니다.** 코덱스에서 승인이 막힌 채로
돌렸더니 모델이 문맥에서 답을 지어냈고, 그것이 정답과 같은 문자열이었습니다. 화면만
보면 성공과 구분되지 않습니다.

| 클라이언트 | 확인할 것 |
|---|---|
| goose | `▸ get_project` 줄 |
| 클로드 코드 | 도구 사용 표시 |
| 코덱스 | `mcp: ost-demo/get_project (completed)` 줄 |

없으면 답이 맞아도 실패로 봅니다.

## 세션 없이 호출되는 것을 직접 보려면

에이전트 없이 `curl` 로도 확인됩니다. `Mcp-Session-Id` 헤더가 없고, 대신 요청 본문의
`_meta` 에 프로토콜 버전과 기능 목록이 실립니다.

```bash
curl -s -X POST http://127.0.0.1:8200/mcp \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientCapabilities":{}}}}'
```

`_meta` 를 빼면 `-32602` 로 거절됩니다. 요청 하나가 자기완결이어야 한다는 것이 이
개정의 핵심입니다.

## 정리

```bash
./scripts/9.cleanup.sh
```

## 검증 환경

2026-08-27~28에 macOS(Apple M4 Pro)에서 확인했습니다. mcp SDK 2.1.1, goose 1.47.0,
클로드 코드, 코덱스 0.148.0 기준입니다. **mcp 2.x에서 `FastMCP` 가 `MCPServer` 로
바뀌었으니**(`from mcp.server.mcpserver import MCPServer`) 예전 예제를 보고 계시면
주의하세요.
