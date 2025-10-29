# Stage 3: Interactive Taint Demonstration

This directory demonstrates how taints affect Stage 3 scoring and winner selection.

## Overview

Stage 3 is where the Kubernetes scheduler evaluates **soft constraints** (preferences) to select the best node. This demo shows how applying taints can change the Stage 3 winner dynamically.

## Test Scenario: Change the Winner

### Initial State (No Taints)

```bash
# Deploy the comprehensive test
kubectl apply -f 99.comprehensive-stage3-winner.yaml

# Check placement
kubectl get pod comprehensive-stage3-winner -n scheduling-demo -o wide
# Expected: w1-k8s (highest score: 180 points)
```

**Scoring without taints:**

| Node | Zone | Disk | Score | Result |
|------|------|------|-------|--------|
| w1-k8s | zone-a | ssd | 180 | ✅ WINNER |
| w2-k8s | zone-a | hdd | 130 | |
| w3-k8s | zone-b | ssd | 80 | |
| w4-k8s | zone-b | hdd | 30 | |

### Scenario 1: Apply NoSchedule Taint to w1-k8s

```bash
# Run interactive script
./taint-node.sh

# Steps in the script:
# 1. Select w1-k8s (using fzf)
# 2. Choose "1) NoSchedule"
# 3. Script shows effect and test commands

# Redeploy the pod
kubectl delete pod comprehensive-stage3-winner -n scheduling-demo
kubectl apply -f 99.comprehensive-stage3-winner.yaml

# Check new placement
kubectl get pod comprehensive-stage3-winner -n scheduling-demo -o wide
# Expected: w2-k8s (NEW WINNER - w1 filtered out in Stage 2)
```

**Scoring after NoSchedule taint on w1-k8s:**

| Node | Status | Score | Result |
|------|--------|-------|--------|
| w1-k8s | FILTERED OUT | N/A | ❌ |
| w2-k8s | Candidate | 130 | ✅ NEW WINNER |
| w3-k8s | Candidate | 80 | |
| w4-k8s | Candidate | 30 | |

### Scenario 2: Switch to PreferNoSchedule Taint

```bash
# Run script again
./taint-node.sh

# Steps:
# 1. Select w1-k8s
# 2. Choose "2) PreferNoSchedule"
# 3. Redeploy

kubectl delete pod comprehensive-stage3-winner -n scheduling-demo
kubectl apply -f 99.comprehensive-stage3-winner.yaml

# Check placement
kubectl get pod comprehensive-stage3-winner -n scheduling-demo -o wide
# Expected: Likely w2-k8s (w1's score is lowered by taint penalty)
```

**Scoring after PreferNoSchedule taint on w1-k8s:**

| Node | Base Score | Taint Penalty | Final Score | Result |
|------|------------|---------------|-------------|--------|
| w1-k8s | 180 | -penalty | ~170 or less | |
| w2-k8s | 130 | 0 | 130 | ✅ LIKELY WINNER |
| w3-k8s | 80 | 0 | 80 | |
| w4-k8s | 30 | 0 | 30 | |

### Scenario 3: Restore Original Winner

```bash
# Remove taints
./taint-node.sh

# Steps:
# 1. Select w1-k8s
# 2. Choose "3) Remove"
# 3. Redeploy

kubectl delete pod comprehensive-stage3-winner -n scheduling-demo
kubectl apply -f 99.comprehensive-stage3-winner.yaml

# Check placement
kubectl get pod comprehensive-stage3-winner -n scheduling-demo -o wide
# Expected: w1-k8s (back to original winner)
```

## Using taint-node.sh

### Features

- **Interactive node selection** with fzf (shows current taints and labels)
- **Three taint operations**:
  - `NoSchedule`: Hard constraint (filters out node in Stage 2)
  - `PreferNoSchedule`: Soft constraint (lowers node score in Stage 3)
  - `Remove`: Removes demo taints
- **Current state display**: Shows node status and taints before operation
- **Test commands**: Provides copy-paste commands to verify changes

### Usage

```bash
# Run the script
./taint-node.sh

# Interactive flow:
# 1. Select node (arrow keys to navigate, Enter to select)
# 2. Review current taints
# 3. Select operation
# 4. Script applies taint and shows test commands
# 5. Follow test commands to observe the effect
```

### Example Output

```
============================================================
Taint worker nodes to change Stage 3 winner
============================================================

Select a node to taint (use arrow keys, type to filter, Enter to select):

w1-k8s               taints=[no-taints]                  zone=zone-a   disk=ssd
w2-k8s               taints=[no-taints]                  zone=zone-a   disk=hdd
w3-k8s               taints=[no-taints]                  zone=zone-b   disk=ssd
w4-k8s               taints=[no-taints]                  zone=zone-b   disk=hdd

============================================================
Taint w1-k8s to change Stage 3 winner
============================================================

Current node w1-k8s status:
NAME     STATUS   ROLES    AGE   VERSION
w1-k8s   Ready    <none>   15d   v1.34.1

Current taints on w1-k8s:
  No taints

Select taint operation:

1) NoSchedule - Hard constraint (filters out node in Stage 2)
2) PreferNoSchedule - Soft constraint (lowers node score in Stage 3)
3) Remove - Remove all demo taints from node
4) Cancel - Exit without changes

✓ NoSchedule taint applied

Effect:
- w1-k8s will be FILTERED OUT in Stage 2 (hard constraint)
- comprehensive-stage3-winner Pod cannot be scheduled to w1-k8s
- Scheduler will pick the next highest scoring node from remaining candidates

To test:
  kubectl delete pod comprehensive-stage3-winner -n scheduling-demo 2>/dev/null || true
  kubectl apply -f 99.comprehensive-stage3-winner.yaml
  kubectl get pod comprehensive-stage3-winner -n scheduling-demo -o wide
```

## Key Takeaways

1. **NoSchedule (Stage 2)**: Completely blocks pod placement → Winner changes from w1 to w2
2. **PreferNoSchedule (Stage 3)**: Lowers node score but doesn't block → May change winner depending on penalty
3. **Stage 3 only matters when Stage 2 leaves multiple candidates**
4. **Interactive testing helps understand scheduling decisions**

## Cleanup

```bash
# Remove demo taints
./taint-node.sh
# Select each tainted node and choose "Remove"

# Delete test pod
kubectl delete pod comprehensive-stage3-winner -n scheduling-demo
```
