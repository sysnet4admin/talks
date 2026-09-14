"""OST 2026 데모용 MCP 서버입니다. 도구는 2개이고 세션은 만들지 않습니다.

발표에서 말한 것을 코드로 보이려고 만들었습니다. 신 스펙(2026-07-28)에는
initialize 핸드셰이크도 Mcp-Session-Id도 없습니다. 이 서버도 세션을 만들지 않고
이전 요청을 저장하지도 않습니다. 그래서 어느 인스턴스가 받아도 같은 결과를 응답합니다.

실행:
  /tmp/ostvenv/bin/python server/ost_server.py
"""
import os

from mcp.server.mcpserver import MCPServer

# mcp 2.x에서 FastMCP가 MCPServer로 이름이 바뀌었습니다.
# 스테이트리스 여부는 서버를 만들 때 정하지 않고 run()에 전송 옵션으로 넘깁니다.
mcp = MCPServer("ost-demo")

# 도구가 조회할 데이터입니다. 실제 서비스라면 이 자리에 DB나 사내 API 호출을 넣습니다.
PROJECTS = {
    "2026-AI-013": {
        "과제명": "에이전트 프로토콜 상호운용성 실증",
        "수행기관": "한국전자통신연구원",
        "기간": "2026-03 ~ 2028-02",
        "단계": "2차년도 진행 중",
    },
    "2025-OSS-041": {
        "과제명": "개방형 컴퓨팅 플랫폼 레퍼런스 구현",
        "수행기관": "한국기계연구원",
        "기간": "2025-01 ~ 2027-12",
        "단계": "3차년도 착수",
    },
}


# 데코레이터 한 줄이 이 함수를 도구로 등록합니다.
# 아래 독스트링과 타입 힌트가 그대로 tools/list의 도구 설명이 됩니다.
@mcp.tool()
def get_project(과제코드: str) -> dict:
    """연구과제 코드로 과제 정보를 조회합니다.

    Args:
        과제코드: 과제 코드입니다. 예) 2026-AI-013
    """
    if 과제코드 not in PROJECTS:
        return {"error": f"과제 코드 {과제코드}를 찾을 수 없습니다.",
                "사용 가능한 코드": list(PROJECTS)}
    return PROJECTS[과제코드]


# 도구는 조회만 하는 것이 아닙니다. 값을 바꾸는 도구도 같은 방식으로 냅니다.
# 이 서버는 메모리에만 씁니다. 실제 서비스라면 여기서 DB를 갱신합니다.
@mcp.tool()
def update_project(과제코드: str, 새단계: str) -> dict:
    """연구과제의 단계를 갱신합니다.

    Args:
        과제코드: 과제 코드입니다. 예) 2026-AI-013
        새단계: 새 단계입니다. 예) 3차년도 착수
    """
    if 과제코드 not in PROJECTS:
        return {"error": f"과제 코드 {과제코드}를 찾을 수 없습니다."}
    before = PROJECTS[과제코드]["단계"]
    PROJECTS[과제코드]["단계"] = 새단계
    return {"과제명": PROJECTS[과제코드]["과제명"], "이전 단계": before, "바뀐 단계": 새단계}


if __name__ == "__main__":
    # 포트와 모드를 환경변수로 받습니다. 데모는 같은 파일로 서버 4대를 실행합니다.
    port = int(os.environ.get("PORT", "8200"))
    stateless = os.environ.get("STATELESS", "1") == "1"

    # 전송 방식은 Streamable HTTP입니다. 일반 웹 서버와 같은 방식으로 동작합니다.
    # stateless_http=False: 구 스펙처럼 세션을 만들어 요청 사이에 저장합니다.
    # stateless_http=True:  요청 사이에 아무것도 저장하지 않습니다.
    # 이 한 줄이 두 스펙을 나눕니다.
    mcp.run(transport="streamable-http", stateless_http=stateless, port=port)
