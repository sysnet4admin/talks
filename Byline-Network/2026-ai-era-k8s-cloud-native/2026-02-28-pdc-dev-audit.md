# pdc-dev Observability Audit Report

**Date**: 2026-02-28
**Cluster**: my-dev-eks-cluster
**Auditor**: Claude Code (AI-Driven SRE Demo)

---

## Summary

| 항목 | 값 |
|------|-----|
| Total Helm Releases | 18 (all deployed) |
| Nodes | 2/2 Ready |
| Pods (Prometheus NS) | 4/4 Running |
| Pods (Grafana NS) | 1/1 Running |
| Pods (Loki NS) | 6/6 Running |
| Pods (Tempo NS) | 7/7 Running |
| Pods (OpenTelemetry NS) | 1/1 Running |
| Pods (Fluentd NS) | 2/2 Running |
| Pods (ArgoCD NS) | 7/7 Running |
| Pods (Argo Rollouts NS) | 1/1 Running |
| Pods (Istio NS) | 7/7 Running |
| ArgoCD Applications | 13 (12 Synced, 1 OutOfSync) |
| **Issues Found** | **4** |

---

## Findings

| # | Severity | Component | Issue | Recommendation |
|---|----------|-----------|-------|----------------|
| 1 | WARNING | ArgoCD App | app-d-ai-server Sync Status가 OutOfSync 상태 | GitOps 소스와 클러스터 상태 불일치 원인 확인 필요. 의도된 변경인지 확인 후 Sync 수행 |
| 2 | WARNING | Prometheus | ServiceMonitor / PodMonitor / PrometheusRule CRD 미설치. Prometheus Operator가 아닌 standalone 모드로 운영 중 | 스크래핑 대상 관리가 정적 설정에 의존하므로, 새 서비스 추가 시 수동 설정 변경 필요. Operator 도입 검토 권장 |
| 3 | INFO | Cluster Summary | 문서상 네임스페이스가 monitoring 단일로 기술되어 있으나, 실제로는 prometheus, grafana, loki, tempo, opentelemetry, fluentd 6개로 분리 운영 중 | 클러스터 요약 문서 업데이트 필요 |
| 4 | INFO | Istio | istio-system 네임스페이스에 별도 Prometheus 인스턴스(prometheus-66d779969f-rp6ln)가 존재하여, 클러스터에 Prometheus가 2개 운영 중 | Istio 전용 메트릭 수집용인지 확인. 가능하다면 메트릭 수집 채널 통합 검토 |

---

## Component Status

| Component | Status | Version | Notes |
|-----------|--------|---------|-------|
| Prometheus | OK | v2.46.0 (chart 24.1.0) | Server 515Mi 메모리 사용. Operator 없이 standalone 운영 |
| Grafana | OK | 10.1.0 (chart 6.59.0) | 1 replica Running |
| Loki | OK | 2.8.4 (chart loki-distributed-0.71.2) | Distributed 모드, 6개 컴포넌트 정상 |
| Tempo | OK | 2.6.0 (chart 1.18.2) | Distributed 모드, 7개 컴포넌트 정상. Ingester 494Mi 메모리 사용 |
| OpenTelemetry Collector | OK | 0.75.0 (chart 0.54.0) | 1 replica Running |
| Fluentd | OK | 1.17.1 (chart 7.0.0) | DaemonSet(1) + StatefulSet(1) 구성 |
| kube-state-metrics | OK | — | Prometheus 네임스페이스에서 Running |
| ArgoCD | OK | v2.8.2 (chart 5.45.0) | 7개 파드 정상. 1개 App OutOfSync |
| Argo Rollouts | OK | — | 1 replica Running |
| Istio | OK | ambient mode (ztunnel 확인) | istiod + CNI + ztunnel 정상 |
| Kiali | OK | — | 1 replica Running |
| Metrics Server | OK | 0.6.4 | kubectl top 정상 동작 확인 |

---

## Resource Usage Highlights

- Prometheus Server: 5m CPU / 515Mi Memory
- Tempo Ingester: 2m CPU / 494Mi Memory (모니터링 컴포넌트 중 최고)
- Tempo Distributor: 2m CPU / 153Mi Memory
- 전반적으로 CPU 사용량은 매우 낮고, 메모리는 안정적 수준

---

## Next Steps (사람이 판단)

1. **WARNING** — app-d-ai-server OutOfSync: 의도된 drift인지 확인 후 조치 여부 결정
2. **WARNING** — Prometheus Operator 미사용: 현재 운영에 문제가 없다면 유지하되, 스크래핑 대상 확장 시 Operator 도입 검토
3. **INFO** — 클러스터 요약 문서(00-cluster-summary.md)의 네임스페이스 정보 업데이트
4. **INFO** — Istio용 Prometheus 이중 운영 구조 정리 검토
