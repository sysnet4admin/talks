# pdc-dev Observability Audit Guide

## Purpose
pdc-dev 클러스터의 옵저버빌리티 스택 현황을 점검합니다.

## Prerequisites
- kubectl context가 `my-dev-eks-cluster`로 설정되어 있을 것

### Pre-validation
```bash
kubectl config current-context
# Expected: arn:aws:eks:<REGION>:*:cluster/my-dev-eks-cluster
```

---

## Step 1: Cluster Health Check

### 1-1. Node Status
```bash
kubectl get nodes -o wide
```
- 확인: 모든 노드가 `Ready` 상태인지
- 확인: 노드 수가 기대값(2~5개)과 일치하는지

### 1-2. Namespace Overview
```bash
kubectl get namespaces
```

---

## Step 2: Helm Release Audit

### 2-1. All Releases
```bash
helm list -A --output table
```
- 확인: 모든 릴리스가 `deployed` 상태인지
- 확인: `failed` 또는 `pending-*` 상태 릴리스가 없는지

### 2-2. Monitoring Stack Versions
```bash
helm list -n monitoring --output table
```
- 기록: 각 릴리스의 chart version과 app version

---

## Step 3: Pod Health — Monitoring

### 3-1. Monitoring Namespace Pods
```bash
kubectl get pods -n monitoring -o wide
```
- 확인: 모든 파드가 `Running` 또는 `Completed` 상태인지
- 확인: `CrashLoopBackOff`, `Error`, `Pending` 파드가 없는지
- 확인: RESTARTS 횟수가 비정상적으로 높지 않은지 (>5)

### 3-2. Resource Usage (if metrics-server available)
```bash
kubectl top pods -n monitoring --sort-by=memory
```

---

## Step 4: Prometheus Targets

### 4-1. Prometheus Target Health (via kubectl)
```bash
kubectl get servicemonitors -A
```
```bash
kubectl get podmonitors -A
```
- 확인: 기대하는 ServiceMonitor/PodMonitor가 존재하는지

---

## Step 5: Log Pipeline

### 5-1. Fluentd DaemonSet
```bash
kubectl get daemonset -n monitoring
```
- 확인: DESIRED = CURRENT = READY

### 5-2. Loki Status
```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki
```
- 확인: 모든 Loki 컴포넌트가 Running 상태인지

---

## Step 6: Tracing Pipeline

### 6-1. Tempo Status
```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=tempo
```

### 6-2. OpenTelemetry Collector
```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=opentelemetry-collector
```

---

## Step 7: ArgoCD & Argo Rollouts

### 7-1. ArgoCD Status
```bash
kubectl get pods -n argocd
```

### 7-2. ArgoCD Applications Health
```bash
kubectl get applications -n argocd
```
- 확인: Sync Status가 `Synced`인지
- 확인: Health Status가 `Healthy`인지

### 7-3. Argo Rollouts
```bash
kubectl get pods -n argocd -l app.kubernetes.io/name=argo-rollouts
```

---

## Step 8: Istio Service Mesh

### 8-1. Istio Components
```bash
kubectl get pods -n istio-system
```

### 8-2. Kiali
```bash
kubectl get pods -n istio-system -l app.kubernetes.io/name=kiali
```

---

## Step 9: Grafana Alert Rules (Optional)

### 9-1. Alert Rules via kubectl
```bash
kubectl get prometheusrules -A
```
- 확인: 알림 규칙이 존재하는지, 몇 개인지

---

## Output: Audit Report

점검 완료 후 아래 형식으로 보고서를 작성합니다:

```
## pdc-dev Observability Audit Report
Date: YYYY-MM-DD

### Summary
- Total Helm Releases: N
- Pods (monitoring): N Running / N Total
- Issues Found: N

### Findings
| # | Severity | Component | Issue | Recommendation |
|---|----------|-----------|-------|----------------|
| 1 | CRITICAL/WARNING/INFO | ... | ... | ... |

### Component Status
| Component | Status | Version | Notes |
|-----------|--------|---------|-------|
| Prometheus | OK/ISSUE | ... | ... |
| Loki | OK/ISSUE | ... | ... |
| ... | ... | ... | ... |
```

---

## Next Steps (사람이 판단)
- CRITICAL 이슈: 즉시 조치 여부 판단
- WARNING 이슈: 일정 잡아서 조치
- INFO: 기록만 하고 모니터링
