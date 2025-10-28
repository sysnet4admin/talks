# Kubernetes Scheduler Deep Dive

Comprehensive demonstration of Kubernetes scheduling across all 5 stages, from admission control to pod-node binding.

## Overview

This demo provides hands-on examples for understanding how Kubernetes schedules pods, covering:

- **Stage 0**: Admission Control (ResourceQuota, LimitRange, DRA validation)
- **Stage 1**: nodeName (Bypass Scheduler)
- **Stage 2**: Scheduler Filter (Hard Constraints)
- **Stage 3**: Scheduler Score (Soft Constraints)
- **Stage 4**: Binding Cycle (Pod-Node Binding)

## Kubernetes Version

- Tested on Kubernetes v1.34

## Directory Structure

```
k8s-scheduler/
├── CLAUDE.md                           # Detailed technical reference
├── comprehensive-complex-scheduling.yaml   # Complex real-world scheduling example
├── stage0/                             # Admission Control demos
│   ├── 00-namespace.yaml
│   ├── 01-limitrange.yaml
│   ├── 02-resourcequota.yaml
│   ├── 03-fail-limitrange.yaml
│   └── 04-pass-limitrange.yaml
├── stage1/                      # nodeName bypass demos
│   ├── 01-pass-nodename-direct.yaml
│   ├── 02-pass-no-nodename.yaml
│   ├── 03-fail-nodename-notfound.yaml
│   ├── 04-pass-nodename-bypass-taint.yaml
│   └── 05-fail-no-nodename-taint.yaml
├── stage2/                      # Filter (hard constraints) demos
│   ├── 01-pass-nodeselector.yaml
│   ├── 02-pass-required-affinity.yaml
│   ├── 03-pass-toleration-required.yaml
│   ├── 04-pass-resource-requests.yaml
│   ├── 05-pass-pod-antiaffinity-1.yaml
│   ├── 06-pass-pod-antiaffinity-2.yaml
│   ├── 07-pass-topology-spread.yaml
│   ├── 08-fail-nodeselector.yaml
│   ├── 09-fail-required-affinity.yaml
│   ├── 10-fail-toleration.yaml
│   ├── 11-fail-resource-requests.yaml
│   ├── 12-fail-topology-spread.yaml
│   └── 99.comprehensive-bypass-stage3.yaml  # Comprehensive: Stage 2 dominates
├── stage3/                      # Score (soft constraints) demos
│   ├── 01-cache-pod.yaml
│   ├── 02-pass-preferred-nodeaffinity.yaml
│   ├── 03-pass-preferred-podaffinity.yaml
│   ├── 04-pass-prefer-no-schedule.yaml
│   ├── 05-pass-no-prefer-toleration.yaml
│   ├── 06-pass-topology-spread-soft.yaml
│   ├── 07-lowscore-preferred-nodeaffinity.yaml
│   ├── 08-lowscore-preferred-podaffinity.yaml
│   ├── 09-lowscore-topology-spread-soft.yaml
│   └── 99.comprehensive-stage3-itself.yaml  # Comprehensive: Stage 3 decides
└── stage4/                      # Binding cycle demos
    ├── 01-block-scheduling-gate.yaml
    ├── 02-pass-no-scheduling-gate.yaml
    ├── 03-storageclass.yaml
    ├── 04-persistentvolume.yaml
    ├── 05-persistentvolumeclaim.yaml
    └── 06-pass-volume-late-binding.yaml
```

## Prerequisites

### Cluster Setup

You must have a Kubernetes cluster with the following node configuration:

| Node | Zone | Disk Type | Taints |
|------|------|-----------|--------|
| w1-k8s | zone-a | ssd | - |
| w2-k8s | zone-a | hdd | - |
| w3-k8s | zone-b | ssd | - |
| w4-k8s | zone-b | hdd | - |
| w5-k8s | zone-c | ssd | gpu:nvidia=NoSchedule |
| w6-k8s | zone-c | hdd | maintenance:true=PreferNoSchedule |

> **Note**: Use the `k8s-cluster-builder` directory to set up this cluster automatically.

### Verify Cluster Configuration

```bash
# Check node labels
kubectl get nodes --show-labels | grep -E "zone=|disktype="

# Check node taints
kubectl describe nodes | grep -A 3 "Taints:"
```

## Quick Start

### Stage 0: Admission Control

Test ResourceQuota and LimitRange enforcement at the API server level:

```bash
# Deploy namespace and quotas
kubectl apply -f stage0/00-namespace.yaml
kubectl apply -f stage0/01-limitrange.yaml
kubectl apply -f stage0/02-resourcequota.yaml

# Test: This should FAIL (exceeds LimitRange)
kubectl apply -f stage0/03-fail-limitrange.yaml

# Test: This should PASS
kubectl apply -f stage0/04-pass-limitrange.yaml

# Verify
kubectl get pods -n scheduling-demo
kubectl describe limitrange demo-limits -n scheduling-demo

# Cleanup
kubectl delete namespace scheduling-demo
```

### Stage 1: nodeName (Scheduler Bypass)

Demonstrates how `nodeName` bypasses all scheduler logic:

```bash
# Test: Direct placement with nodeName
kubectl apply -f stage1/01-pass-nodename-direct.yaml

# Test: Scheduler handles placement
kubectl apply -f stage1/02-pass-no-nodename.yaml

# Test: Non-existent node (stays Pending)
kubectl apply -f stage1/03-fail-nodename-notfound.yaml

# Test: Bypass taint check (succeeds despite no toleration)
kubectl apply -f stage1/04-pass-nodename-bypass-taint.yaml

# Test: Scheduler enforces taint (fails without toleration)
kubectl apply -f stage1/05-fail-no-nodename-taint.yaml

# Check results
kubectl get pods -o wide

# Cleanup
kubectl delete pods -l 'test in (stage1-nodename,stage1-scheduler,stage1-bypass,stage1-fail)'
```

### Stage 2: Scheduler Filter (Hard Constraints)

All conditions must be satisfied:

```bash
# Deploy all stage2 tests (including comprehensive example)
kubectl apply -f stage2/

# Check successful placements
kubectl get pods -l test=stage2-filter -o wide

# Check failed pods (remain Pending)
kubectl get pods -l test=stage2-fail -o wide

# Describe a failed pod to see why
kubectl describe pod stage2-fail-nodeselector

# Check comprehensive example (Stage 2 makes Stage 3 meaningless)
kubectl get pod comprehensive-bypass-stage3 -n scheduling-demo -o wide
# Expected: w5-k8s (only candidate after Stage 2 Filter)
# Note: Stage 3 preferences (zone-a, HDD) are ignored because w5-k8s is the only option

# Cleanup
kubectl delete pods -l 'test in (stage2-filter,stage2-fail)'
kubectl delete pod comprehensive-bypass-stage3 -n scheduling-demo
```

### Stage 3: Scheduler Score (Soft Constraints)

Preferences influence placement but don't block scheduling:

```bash
# Deploy cache pod first (needed for PodAffinity tests)
kubectl apply -f stage3/01-cache-pod.yaml

# Deploy pass tests (high scores - good matches)
kubectl apply -f stage3/02-pass-preferred-nodeaffinity.yaml
kubectl apply -f stage3/03-pass-preferred-podaffinity.yaml
kubectl apply -f stage3/04-pass-prefer-no-schedule.yaml
kubectl apply -f stage3/05-pass-no-prefer-toleration.yaml
kubectl apply -f stage3/06-pass-topology-spread-soft.yaml

# Deploy lowscore tests (low scores - poor matches)
kubectl apply -f stage3/07-lowscore-preferred-nodeaffinity.yaml
kubectl apply -f stage3/08-lowscore-preferred-podaffinity.yaml
kubectl apply -f stage3/09-lowscore-topology-spread-soft.yaml

# All pods should be Running, but on different nodes
kubectl get pods -l 'test in (stage3-score,stage3-lowscore)' -o wide

# Compare: Pass vs Lowscore placements
kubectl get pod stage3-pass-preferred-podaffinity -o wide
kubectl get pod stage3-lowscore-preferred-podaffinity -o wide

# Check comprehensive example (Stage 3 actually matters)
kubectl get pod comprehensive-stage3-itself -n scheduling-demo -o wide
# Expected: w1-k8s (highest score: 180 points)
# Scoring: w1(180) > w2(130) > w3(80) > w4(30)
# Note: Stage 2 left 4 candidates, Stage 3 picked the best

# Cleanup
kubectl delete pods -l 'test in (stage3-score,stage3-lowscore)'
kubectl delete pod comprehensive-stage3-itself -n scheduling-demo
kubectl delete pod cache-pod
```

### Stage 4: Binding Cycle

Control the final binding phase:

```bash
# Deploy storage infrastructure
kubectl apply -f stage4/03-storageclass.yaml
kubectl apply -f stage4/04-persistentvolume.yaml
kubectl apply -f stage4/05-persistentvolumeclaim.yaml

# Deploy pods
kubectl apply -f stage4/01-block-scheduling-gate.yaml
kubectl apply -f stage4/02-pass-no-scheduling-gate.yaml
kubectl apply -f stage4/06-pass-volume-late-binding.yaml

# Check: Gated pod should be "SchedulingGated"
kubectl get pod stage4-block-scheduling-gate -o wide

# Check: schedulingGates are present
kubectl get pod stage4-block-scheduling-gate -o jsonpath='{.spec.schedulingGates}'

# Unblock the gated pod
kubectl patch pod stage4-block-scheduling-gate \
  --type=json -p='[{"op": "remove", "path": "/spec/schedulingGates"}]'

# Verify: All pods should now be Running
kubectl get pods -l 'test in (stage4-pass,stage4-block)' -o wide

# Check: PVC should be Bound
kubectl get pvc

# Cleanup
kubectl delete pods -l 'test in (stage4-pass,stage4-block)'
kubectl delete pvc demo-pvc
kubectl delete pv demo-pv-w1
kubectl delete sc late-binding-sc
```

## Key Concepts

### Stage 0: Admission Control
- Validates resource requests before reaching scheduler
- Enforces namespace quotas (ResourceQuota) and container limits (LimitRange)
- Validates ResourceClaims for DRA (when applicable)
- Rejects invalid pods immediately at API server level

### Stage 1: nodeName
- **Bypasses all scheduler logic**
- Directly assigns pod to specified node
- Ignores: nodeSelector, affinity, tolerations, taints
- Use case: Manual placement, testing

### Stage 2: Filter (Hard Constraints)
- **All** conditions must pass
- Filtering criteria:
  - NodeSelector
  - NodeAffinity (required)
  - Taints/Tolerations
  - Resource requests
  - PodAffinity/PodAntiAffinity (required)
  - TopologySpreadConstraints (whenUnsatisfiable: DoNotSchedule)
- Failure = Pod stays Pending

### Stage 3: Score (Soft Constraints)
- **Preferences** influence placement
- Scoring criteria:
  - NodeAffinity (preferred)
  - PodAffinity/PodAntiAffinity (preferred)
  - PreferNoSchedule taints
  - TopologySpreadConstraints (whenUnsatisfiable: ScheduleAnyway)
  - Resource balancing
- Failure = Still schedules, but on less optimal node

### Stage 4: Binding Cycle
Five extension points:
1. **Reserve**: Reserve resources (volumes, devices)
2. **Permit**: Gate/approval (schedulingGates)
3. **PreBind**: Prepare resources (volume binding)
4. **Bind**: Update API server
5. **PostBind**: Notifications

## Comprehensive Tests

Three comprehensive examples demonstrate how scheduling stages interact:

### 1. Complex Real-World Scheduling (comprehensive-complex-scheduling.yaml)

Demonstrates a realistic production scenario with multiple constraints working together:

```bash
# Deploy cache pod first (needed for PodAffinity)
kubectl apply -f stage3/01-cache-pod.yaml

# Deploy complex scheduling test
kubectl apply -f comprehensive-complex-scheduling.yaml

# Check placement
kubectl get pod comprehensive-scheduling-test -n scheduling-demo -o wide
# Expected: w1-k8s (passes Stage 2 filters, highest Stage 3 score)

# Review how all constraints work together
kubectl describe pod comprehensive-scheduling-test -n scheduling-demo

# Cleanup
kubectl delete pod comprehensive-scheduling-test -n scheduling-demo
kubectl delete pod cache-pod -n scheduling-demo
```

This pod combines:
- **Stage 2 (Hard)**: nodeSelector (ssd), required NodeAffinity (zone-a/b), NoSchedule toleration (gpu), PodAntiAffinity, TopologySpread, Resource requests
- **Stage 3 (Soft)**: preferred NodeAffinity (zone-a), preferred PodAffinity (cache), PreferNoSchedule toleration (maintenance)
- **Stage 4**: Normal binding

**Key lesson**: Real-world pods often use multiple Stage 2 and Stage 3 constraints together. Stage 2 narrows candidates (w1, w3), then Stage 3 picks the best (w1).

### 2. Stage 2 Makes Stage 3 Meaningless (stage2/99.comprehensive-bypass-stage3.yaml)

Demonstrates when hard constraints leave only one candidate, making soft constraints irrelevant:

```bash
# Deploy the test (from stage2 directory)
kubectl apply -f stage2/99.comprehensive-bypass-stage3.yaml

# Check placement
kubectl get pod comprehensive-bypass-stage3 -n scheduling-demo -o wide
# Expected: w5-k8s (zone-c, SSD)

# Review the contradiction
kubectl describe pod comprehensive-bypass-stage3 -n scheduling-demo
# Note: Stage 3 prefers zone-a + HDD
# But: w5-k8s is zone-c + SSD (opposite!)
# Why: Stage 2 Filter left only w5-k8s as a candidate
#      Stage 3 preferences had ZERO impact

# Cleanup
kubectl delete pod comprehensive-bypass-stage3 -n scheduling-demo
```

**Key lesson**: Strong Stage 2 filters can make Stage 3 preferences meaningless.

**Location**: This example is in `stage2/` because it demonstrates the **power of Stage 2 filters** - when Stage 2 is too restrictive, Stage 3 becomes irrelevant.

### 3. Stage 3 Actually Matters (stage3/99.comprehensive-stage3-itself.yaml)

Demonstrates when soft constraints determine the final placement:

```bash
# Deploy the test (from stage3 directory)
kubectl apply -f stage3/99.comprehensive-stage3-itself.yaml

# Check placement
kubectl get pod comprehensive-stage3-itself -n scheduling-demo -o wide
# Expected: w1-k8s (highest score: 180 points)

# Review the scoring
kubectl describe pod comprehensive-stage3-itself -n scheduling-demo
# Scoring breakdown:
# - w1-k8s: zone-a (100) + SSD (80) = 180 points ← WINNER!
# - w2-k8s: zone-a (100) + HDD (30) = 130 points
# - w3-k8s: zone-b (0) + SSD (80) = 80 points
# - w4-k8s: zone-b (0) + HDD (30) = 30 points

# Cleanup
kubectl delete pod comprehensive-stage3-itself -n scheduling-demo
```

**Key lesson**: When Stage 2 leaves multiple candidates, Stage 3 picks the best match.

**Location**: This example is in `stage3/` because it demonstrates the **importance of Stage 3 scoring** - when Stage 2 allows multiple nodes, Stage 3 decides the winner.

### Comparison Summary

| Test | Location | Stage 2 Candidates | Stage 3 Impact | Final Node | Scenario |
|------|----------|-------------------|----------------|------------|----------|
| comprehensive-complex-scheduling.yaml | Root | w1, w3 (multiple filters) | **Picks the best** | w1-k8s | Real-world: Both stages matter |
| 99.comprehensive-bypass-stage3.yaml | stage2/ | Only w5-k8s | **No impact** | w5-k8s (forced) | Stage 2 too strong |
| 99.comprehensive-stage3-itself.yaml | stage3/ | w1, w2, w3, w4 | **Decides placement** | w1-k8s (best score) | Stage 3 is the decider |

**Learning Path**:
1. Start with individual stage examples (stage0/ → stage1/ → stage2/ → stage3/ → stage4/)
2. Each stage includes a comprehensive example at the end (99.xxx.yaml)
3. Finish with the root comprehensive-complex-scheduling.yaml for the complete picture

## Troubleshooting

### Pod stays Pending

```bash
# Check events
kubectl describe pod <pod-name>

# Look for FailedScheduling events
kubectl get events --sort-by='.lastTimestamp' | grep FailedScheduling
```

### Common issues

- **Stage 0**: ResourceQuota or LimitRange violations (rejected before scheduling)
- **Stage 1**: nodeName to non-existent node (stays Pending)
- **Stage 2**: Missing toleration for tainted node (no nodes available)
- **Stage 2**: NodeSelector doesn't match any node (no nodes available)
- **Stage 2**: Insufficient resources on all nodes (no nodes available)
- **Stage 3**: All pods schedule successfully (soft constraints don't block)
- **Stage 4**: schedulingGates blocking binding (SchedulingGated status)

## Advanced Topics

### DRA (Dynamic Resource Allocation)

Dynamic Resource Allocation is a Kubernetes feature for managing specialized hardware resources (GPUs, FPGAs, etc.) through a more flexible API than traditional resource requests.

**Why not included in this demo:**
- Requires DRA-compatible drivers (e.g., NVIDIA GPU Operator with DRA support)
- Requires actual hardware devices or device plugins
- Complex setup beyond basic Kubernetes cluster requirements
- Not suitable for VM-based demo environments

**Where to learn more:**
- DRA examples and detailed documentation are available in `CLAUDE.md`
- DRA operates across multiple scheduling stages (Stage 0 Validation, Stage 2 Filter, Stage 3 Score, Stage 4 Binding)
- Feature is enabled by default in Kubernetes v1.34+ (core API stable; some features may require feature gates)

**If you want to test DRA:**
1. Install a DRA-compatible driver in your cluster
2. Verify ResourceSlices exist: `kubectl get resourceslices`
3. Create DeviceClass for your devices
4. Refer to examples in `CLAUDE.md`

### Custom Scheduler

To test with a custom scheduler:

```yaml
spec:
  schedulerName: my-custom-scheduler
```

## File Naming Convention

- **pass**: Expected to succeed
- **fail**: Expected to fail (Pending)
- **block**: Temporarily blocked (SchedulingGated)
- **lowscore**: Succeeds but with lower score

## Documentation

See `CLAUDE.md` for detailed technical reference including:
- Complete scheduling flow diagrams
- Extension point documentation
- Advanced configuration examples

## Best Practices

1. **Start with Stage 0**: Understand admission control first
2. **Progress sequentially**: Each stage builds on previous concepts
3. **Compare pass/fail**: Learn from both successes and failures
4. **Use kubectl describe**: Events explain scheduling decisions
5. **Clean up between tests**: Avoid resource conflicts

## References

- [Kubernetes Scheduling Framework](https://kubernetes.io/docs/concepts/scheduling-eviction/scheduling-framework/)
- [Pod Scheduling Readiness](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-scheduling-readiness/)
- [Dynamic Resource Allocation](https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/)

## License

Educational material for KubeCon NA 2025.
