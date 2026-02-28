# pdc-dev Cluster Summary

## Overview
- **Cluster**: my-dev-eks-cluster (EKS, <REGION>)
- **Kubernetes**: v1.33
- **Nodes**: 2 worker nodes
  - `api` node group: <INSTANCE_TYPE> (2 vCPU, 16 GiB) — min:2, max:3
  - `telemetry` node group: <INSTANCE_TYPE> (2 vCPU, 16 GiB) — min:1, max:2
- **Networking**: AWS VPC CNI with prefix delegation

## Observability Stack

| Component | Version | Namespace | Purpose |
|-----------|---------|-----------|---------|
| Prometheus | v2.46 | monitoring | Metrics collection |
| Grafana | 10.1 | monitoring | Dashboards & alerts |
| Loki | 2.8.4 (distributed) | monitoring | Log aggregation |
| Tempo | 2.6 | monitoring | Distributed tracing |
| OpenTelemetry Collector | 0.75 | monitoring | Trace/metric pipeline |
| Fluentd | (DaemonSet) | monitoring | Log forwarding to Loki |
| kube-state-metrics | — | monitoring | K8s object metrics |

## CI/CD & Platform

| Component | Version | Namespace | Purpose |
|-----------|---------|-----------|---------|
| ArgoCD | v2.8.2 | argocd | GitOps deployment |
| Argo Rollouts | v1.7.2 | argocd | Progressive delivery |
| Istio | 1.26.2 | istio-system | Service mesh (ambient mode) |
| Kiali | v2.8 | istio-system | Service mesh observability |

## Domains
- Grafana: grafana.example.com
- ArgoCD: argo.example.com

## Application Namespaces
- app-a, app-b, app-c, app-d

## Key Endpoints for Audit
- Prometheus: `kubectl port-forward -n monitoring svc/prometheus 9090:9090`
- Grafana API: `kubectl port-forward -n monitoring svc/grafana 3000:80`
