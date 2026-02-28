# pdc-dev Demo Environment — AI-Driven SRE

## Cluster Information
- **Cluster**: my-dev-eks-cluster
- **Region**: <REGION>
- **Purpose**: 웨비나 데모용 옵저버빌리티 감사(Audit) 시연

## Ground Rules (Priority Order)

### 1. READ-ONLY Operations Only
This is an audit task. **No modifications allowed.**

**Allowed commands:**
- `kubectl get`, `kubectl describe`, `kubectl logs`
- `helm list`, `helm get values`, `helm get notes`
- `curl` (Grafana/Prometheus API, GET only)

**Forbidden commands:**
- `kubectl apply`, `kubectl delete`, `kubectl edit`, `kubectl patch`
- `helm install`, `helm upgrade`, `helm uninstall`, `helm rollback`
- Any `aws` CLI commands that modify resources

### 2. Execution Guide
- Read `claude-context/00-cluster-summary.md` before any work
- Run only commands from `command-guardrails/observability-audit.md`
- Follow the step order defined in the guardrail

### 3. Output Rules
- Summarize findings in a structured audit report
- Flag anomalies with severity: CRITICAL / WARNING / INFO
- Do NOT attempt to fix any issues — report only

### 4. Sensitive Information
- Do NOT display or log AWS Account IDs, IAM role ARNs, or secret values
- Mask ECR image URLs in output (show repository name only)
