# pdc-dev Demo Memory

## Cluster Facts
- pdc-dev는 2개 노드그룹(api, telemetry)으로 운영
- monitoring 네임스페이스에 옵저버빌리티 스택 집중 배치
- Istio ambient mode 사용 중 (ztunnel)

## Known Issues (from previous audits)
- Loki distributed 모드에서 간헐적으로 compactor 파드 재시작 관찰됨
- Fluentd 버퍼가 노드 디스크 사용량에 영향을 줄 수 있음 — top pods로 확인 필요

## Audit History
- (데모 시작 전 비어 있음 — 감사 수행 후 결과가 여기에 기록됨)
