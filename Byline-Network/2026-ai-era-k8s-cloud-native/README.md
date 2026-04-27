
## AI-Driven SRE: AI와 함께 만드는 쿠버네티스 운영 표준
- **Date:** Tuesday March 24, 2026
- **Event:** 바이라인네트워크 | AI 시대를 준비하는 쿠버네티스 - 클라우드 네이티브의 재발견
- **Link:** [바이라인네트워크 | 2주 걸리던 SRE 업무, AI 동료와 하니 이틀로 줄어](https://byline.network/2026/04/23-592)
- **Youtube:** [[쿠버네티스 웨비나] AI-Driven SRE: AI와 함께 만드는 쿠버네티스 운영 표준ㅣ조훈 CNCF Ambassador](https://youtu.be/VhmC-XqTf1k?si=beUpWTi4HtBzn0JG)
- **KO-Doc:** [AI-Driven SRE - AI와 함께 만드는 쿠버네티스 운영 표준_Final_v1.2.pdf](https://github.com/sysnet4admin/talks/blob/main/Byline-Network/2026-ai-era-k8s-cloud-native/%5BSpeaker%20Deck%5D%20AI-Driven%20SRE%20-%20AI%EC%99%80%20%ED%95%A8%EA%BB%98%20%EB%A7%8C%EB%93%9C%EB%8A%94%20%EC%BF%A0%EB%B2%84%EB%84%A4%ED%8B%B0%EC%8A%A4%20%EC%9A%B4%EC%98%81%20%ED%91%9C%EC%A4%80_Final_v1.2.pdf)
- **DEMO-Dir:** [demo](demo)
---
- **EN-Doc:** None

### Abstract
Command Guardrails 패턴과 4계층 문서 체계(Four-Layer Document Architecture)를 통해 AI 코파일럿(Claude Code)을 활용한 쿠버네티스 운영 표준을 제시합니다.

### Key Topics
| # | Topic | Description |
|---|-------|-------------|
| 1 | **문제 인식** | 1인 SRE가 대규모 EKS 마이그레이션을 수행할 때 전통적 접근(IaC, Runbook, 자동화 스크립트)의 한계 |
| 2 | **4계층 문서 체계** | work-plans → claude-context → command-guardrails → helm-values 로 이어지는 추상→구체 문서 설계 |
| 3 | **GitAIOps** | Git(버전 관리 + 리뷰 + 변경 이력) + AI(맥락 이해 + 가이드 실행 + 결과 검증) = GitAIOps |
| 4 | **운영 전략** | AI에게 맡기는 것의 경계, Memory 시스템을 통한 맥락 보존 |
| 5 | **생산성 변화** | DEV 환경 구축 1~2주→2일, 클러스터 감사 수시간→30분 등 실제 생산성 비교 |
| 6 | **Live Demo** | 옵저버빌리티 감사(Observability Audit) - 9단계 Command Guardrail 실행 |

### Four-Layer Document Architecture
```
Layer 1: work-plans            — 사람이 읽는 계획서 (Why + How + 트레이드오프)
Layer 2: claude-context        — AI를 위해 증류한 문서 (프로젝트 상태, 환경 값)
Layer 3: command-guardrails    — AI의 행동 제어 (단계별 실행 가이드, 순서 강제)
Layer 4: helm-values / IaC     — 값의 고정 (해석의 여지 제거, 재현 가능한 배포)
```

### Demo Structure
```
demo/
├── CLAUDE.md                        # AI 행동 규칙 (READ-ONLY 전용)
├── claude-context/
│   └── 00-cluster-summary.md        # 클러스터 맥락
├── command-guardrails/
│   └── observability-audit.md       # 9단계 감사 실행 가이드
└── memory/
    └── MEMORY.md                    # 누적 기억
```
