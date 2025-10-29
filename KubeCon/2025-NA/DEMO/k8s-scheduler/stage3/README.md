# Stage 3: Scheduler Score (Soft Constraints)

Stage 3 is where the Kubernetes scheduler evaluates **soft constraints** (preferences) to select the best node from the candidates that passed Stage 2 filtering.

## Overview

Unlike Stage 2 (hard constraints that can block scheduling), Stage 3 preferences influence placement but **never prevent a pod from being scheduled**. The scheduler assigns scores to each candidate node and selects the one with the highest score.

## Key Concepts

### Scoring Plugins

The scheduler uses multiple plugins to calculate node scores:

1. **NodeAffinity**: Preferred node labels
2. **PodAffinity/PodAntiAffinity**: Preferred pod co-location/separation
3. **TaintToleration**: PreferNoSchedule taint penalties
4. **TopologySpreadConstraints**: Soft topology distribution (whenUnsatisfiable: ScheduleAnyway)
5. **NodeResourcesFit**: Resource balancing
6. **ImageLocality**: Prefer nodes with cached images

Each plugin assigns a score (0-100), and the final score is a weighted sum of all plugin scores.

## Files in This Directory

### Individual Tests

- `01-cache-pod.yaml` - Cache pod for PodAffinity tests
- `02-pass-preferred-nodeaffinity.yaml` - High score with preferred node affinity
- `03-pass-preferred-podaffinity.yaml` - High score with preferred pod affinity
- `04-pass-prefer-no-schedule.yaml` - No penalty with PreferNoSchedule toleration
- `05-pass-no-prefer-toleration.yaml` - Lower score without PreferNoSchedule toleration
- `06-pass-topology-spread-soft.yaml` - Soft topology spread (schedules even if unbalanced)
- `07-lowscore-preferred-nodeaffinity.yaml` - Low score with non-matching preferences
- `08-lowscore-preferred-podaffinity.yaml` - Low score with non-matching pod affinity
- `09-lowscore-topology-spread-soft.yaml` - Lower score due to topology imbalance

### Comprehensive Test

- `99.comprehensive-stage3-winner.yaml` - Demonstrates Stage 3 as the deciding factor
  - Stage 2 leaves 4 candidates (w1, w2, w3, w4)
  - Stage 3 picks the winner based on highest score
  - Expected: w1-k8s (180 points)

### Interactive Tool

- `taint-node.sh` - Interactive script to manage node taints
  - fzf-based node selection with taint display
  - Apply NoSchedule or PreferNoSchedule taints
  - Remove taints
  - Observe how taints change Stage 3 winner

## Quick Start

### 1. Deploy Cache Pod (for PodAffinity tests)

```bash
kubectl apply -f 01-cache-pod.yaml
```

### 2. Deploy High Score Tests

These pods match the preferences and get high scores:

```bash
kubectl apply -f 02-pass-preferred-nodeaffinity.yaml
kubectl apply -f 03-pass-preferred-podaffinity.yaml
kubectl apply -f 04-pass-prefer-no-schedule.yaml
kubectl apply -f 05-pass-no-prefer-toleration.yaml
kubectl apply -f 06-pass-topology-spread-soft.yaml
```

### 3. Deploy Low Score Tests

These pods don't match preferences but still schedule (just on less optimal nodes):

```bash
kubectl apply -f 07-lowscore-preferred-nodeaffinity.yaml
kubectl apply -f 08-lowscore-preferred-podaffinity.yaml
kubectl apply -f 09-lowscore-topology-spread-soft.yaml
```

### 4. Verify Placement

```bash
# Check all pods - all should be Running
kubectl get pods -o wide

# Compare high vs low score placements
kubectl get pod stage3-pass-preferred-nodeaffinity -o wide
kubectl get pod stage3-lowscore-preferred-nodeaffinity -o wide
```

### 5. Test Comprehensive Example

```bash
# Deploy comprehensive test
kubectl apply -f 99.comprehensive-stage3-winner.yaml

# Check placement
kubectl get pod comprehensive-stage3-winner -n scheduling-demo -o wide
# Expected: w1-k8s (180 points)

# Review scoring breakdown in events
kubectl describe pod comprehensive-stage3-winner -n scheduling-demo
```

## Interactive Demonstration: Change the Winner

Use `taint-node.sh` to dynamically change which node wins in Stage 3:

```bash
# Run the interactive script
./taint-node.sh

# Example flow:
# 1. Select w1-k8s (current winner)
# 2. Apply NoSchedule taint
# 3. Redeploy pod:
kubectl delete pod comprehensive-stage3-winner -n scheduling-demo
kubectl apply -f 99.comprehensive-stage3-winner.yaml

# 4. New winner: w2-k8s (w1 filtered out in Stage 2)
kubectl get pod comprehensive-stage3-winner -n scheduling-demo -o wide
```

### Script Features

- **fzf integration**: Interactive node selection with taints display
- **Current state**: Shows existing taints before applying changes
- **Three operations**:
  - NoSchedule: Filters out node in Stage 2 (hard constraint)
  - PreferNoSchedule: Lowers node score in Stage 3 (soft constraint)
  - Remove: Removes demo taints
- **Test commands**: Provides commands to verify the changes

## Scoring Example

For `99.comprehensive-stage3-winner.yaml` without taints:

| Node | Zone | Disk | Zone Score (weight 100) | Disk Score (weight 80) | Total | Result |
|------|------|------|------------------------|------------------------|-------|--------|
| w1-k8s | zone-a | ssd | 100 | 80 | **180** | ✅ WINNER |
| w2-k8s | zone-a | hdd | 100 | 30 | 130 | |
| w3-k8s | zone-b | ssd | 0 | 80 | 80 | |
| w4-k8s | zone-b | hdd | 0 | 30 | 30 | |

### After Applying NoSchedule Taint to w1-k8s

| Node | Status | Total Score | Result |
|------|--------|-------------|--------|
| w1-k8s | FILTERED OUT (Stage 2) | N/A | ❌ |
| w2-k8s | Candidate | 130 | ✅ NEW WINNER |
| w3-k8s | Candidate | 80 | |
| w4-k8s | Candidate | 30 | |

### After Applying PreferNoSchedule Taint to w1-k8s

| Node | Zone | Disk | Base Score | Taint Penalty | Final | Result |
|------|------|------|------------|---------------|-------|--------|
| w1-k8s | zone-a | ssd | 180 | -penalty | ~170 | (depends on implementation) |
| w2-k8s | zone-a | hdd | 130 | 0 | 130 | ✅ LIKELY WINNER |
| w3-k8s | zone-b | ssd | 80 | 0 | 80 | |
| w4-k8s | zone-b | hdd | 30 | 0 | 30 | |

## Key Differences: Pass vs Lowscore

### Pass Tests (High Score)
- Preferences **match** node characteristics
- Higher scores → Better placement
- More likely to get optimal nodes

### Lowscore Tests (Low Score)
- Preferences **don't match** node characteristics
- Lower scores → Less optimal placement
- Still schedules (unlike Stage 2 failures)
- May land on less desirable nodes

## Stage 2 vs Stage 3 Comparison

| Aspect | Stage 2 (Filter) | Stage 3 (Score) |
|--------|------------------|-----------------|
| Constraint Type | Hard (required) | Soft (preferred) |
| Failure Impact | Pod stays Pending | Pod still schedules |
| Example | requiredDuringScheduling | preferredDuringScheduling |
| Taint Effect | NoSchedule | PreferNoSchedule |
| TopologySpread | DoNotSchedule | ScheduleAnyway |

## When Stage 3 Matters

Stage 3 is only meaningful when **Stage 2 leaves multiple candidates**:

- ✅ **Stage 3 matters**: `99.comprehensive-stage3-winner.yaml`
  - Stage 2 leaves 4 candidates (w1, w2, w3, w4)
  - Stage 3 picks the best (w1-k8s with 180 points)

- ❌ **Stage 3 irrelevant**: `../stage2/99.comprehensive-bypass-stage3.yaml`
  - Stage 2 leaves only 1 candidate (w5-k8s)
  - Stage 3 preferences have no impact (no choice to make)

## Troubleshooting

### All pods schedule successfully
This is expected! Stage 3 never blocks scheduling. If you see Pending pods, check Stage 2 constraints.

### Pods landing on unexpected nodes
Check scoring preferences - they influence but don't guarantee placement. Use `kubectl describe pod` to see scheduling events and understand the decision.

### PreferNoSchedule seems ignored
PreferNoSchedule only lowers score, doesn't prevent scheduling. If the tainted node still has the highest score after penalty, it will be selected.

## Best Practices

1. **Use Stage 3 for optimization**: Prefer certain nodes but allow flexibility
2. **Combine with Stage 2**: Use hard constraints to eliminate unsuitable nodes first
3. **Test with taints**: Use `taint-node.sh` to understand scoring dynamics
4. **Compare pass/lowscore**: Learn how preferences affect placement
5. **Monitor scoring**: Use `kubectl describe pod` to see scheduler decisions

## References

- [Kubernetes Scheduling Framework](https://kubernetes.io/docs/concepts/scheduling-eviction/scheduling-framework/)
- [Node Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity)
- [Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)

## Cleanup

```bash
# Delete all stage3 pods
kubectl delete pods -l 'test in (stage3-score,stage3-lowscore)'
kubectl delete pod comprehensive-stage3-winner -n scheduling-demo
kubectl delete pod cache-pod -n scheduling-demo

# Remove any demo taints
./taint-node.sh
# Select each node and choose "Remove"
```
