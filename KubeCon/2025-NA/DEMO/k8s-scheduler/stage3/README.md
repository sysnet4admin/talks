# Stage 3: Interactive Taint Demonstration

This directory demonstrates how taints affect Stage 3 scoring and winner selection through three scenarios.

## Overview

Stage 3 is where the Kubernetes scheduler evaluates **soft constraints** (preferences) to select the best node. This demo shows how taints dynamically change the Stage 3 winner based on scoring.

## Three Test Scenarios

### Scenario 1: Baseline (No Taints)

**Objective**: Establish baseline without using taint-node.sh

```bash
# Deploy the comprehensive test
kubectl apply -f 99.comprehensive-stage3-winner.yaml

# Check placement
kubectl get pod comprehensive-stage3-winner -o wide
# Expected: w1-k8s (highest score: 180 points)

# Verify scheduling decision
kubectl describe pod comprehensive-stage3-winner | grep -A5 Events
```

**Scoring without taints:**

| Node | Zone | Disk | Zone Score (weight 100) | Disk Score (weight 80) | Total | Result |
|------|------|------|------------------------|------------------------|-------|--------|
| w1-k8s | zone-a | ssd | 100 | 80 | **180** | ✅ WINNER |
| w2-k8s | zone-a | hdd | 100 | 30 | 130 | |
| w3-k8s | zone-b | ssd | 0 | 80 | 80 | |
| w4-k8s | zone-b | hdd | 0 | 30 | 30 | |

**Key Point**: w1-k8s wins because it matches both preferences (zone-a + ssd)

---

### Scenario 2: Taint w1-k8s (Winner Changes)

**Objective**: Use taint-node.sh to taint w1-k8s and observe winner change to w2-k8s

```bash
# Apply taint to w1-k8s using interactive script
./taint-node.sh

# Interactive steps:
# 1. Select w1-k8s (using fzf)
# 2. Choose "1) NoSchedule - Hard constraint (filters out node in Stage 2)"
# 3. Observe the effect message

# Redeploy the pod
kubectl delete pod comprehensive-stage3-winner
kubectl apply -f 99.comprehensive-stage3-winner.yaml

# Check new placement
kubectl get pod comprehensive-stage3-winner -o wide
# Expected: w2-k8s (NEW WINNER - w1 filtered out in Stage 2)

# Verify w1 is filtered out
kubectl describe pod comprehensive-stage3-winner | grep -A5 Events
```

**Scoring after NoSchedule taint on w1-k8s:**

| Node | Status | Score | Result |
|------|--------|-------|--------|
| w1-k8s | FILTERED OUT (Stage 2) | N/A | ❌ Eliminated |
| w2-k8s | Candidate | 130 | ✅ NEW WINNER |
| w3-k8s | Candidate | 80 | |
| w4-k8s | Candidate | 30 | |

**Key Point**: w1-k8s is eliminated in Stage 2 Filter. w2-k8s becomes the winner (highest score among remaining candidates)

---

### Scenario 3: Taint w2-k8s Also (Winner Changes Again)

**Objective**: Add taint to w2-k8s to show how winner moves to w3-k8s based on scores

```bash
# Keep w1-k8s tainted, now taint w2-k8s as well
./taint-node.sh

# Interactive steps:
# 1. Select w2-k8s (using fzf)
# 2. Choose "1) NoSchedule - Hard constraint (filters out node in Stage 2)"
# 3. Observe the effect message

# Redeploy the pod
kubectl delete pod comprehensive-stage3-winner
kubectl apply -f 99.comprehensive-stage3-winner.yaml

# Check new placement
kubectl get pod comprehensive-stage3-winner -o wide
# Expected: w3-k8s (NEW WINNER - w1 and w2 filtered out)

# Verify w1 and w2 are filtered out
kubectl describe pod comprehensive-stage3-winner | grep -A5 Events
```

**Scoring after NoSchedule taints on both w1-k8s and w2-k8s:**

| Node | Status | Score | Result |
|------|--------|-------|--------|
| w1-k8s | FILTERED OUT (Stage 2) | N/A | ❌ Eliminated |
| w2-k8s | FILTERED OUT (Stage 2) | N/A | ❌ Eliminated |
| w3-k8s | Candidate | 80 | ✅ NEW WINNER |
| w4-k8s | Candidate | 30 | |

**Key Point**: Both w1-k8s and w2-k8s are eliminated. w3-k8s wins despite lower score (only ssd matches, zone-b doesn't)

---

### Cleanup: Restore Original State

```bash
# Remove all taints to restore baseline
./taint-node.sh

# Remove taint from w1-k8s:
# 1. Select w1-k8s
# 2. Choose "3) Remove - Remove all demo taints from node"

./taint-node.sh

# Remove taint from w2-k8s:
# 1. Select w2-k8s
# 2. Choose "3) Remove - Remove all demo taints from node"

# Redeploy and verify w1-k8s is back as winner
kubectl delete pod comprehensive-stage3-winner
kubectl apply -f 99.comprehensive-stage3-winner.yaml
kubectl get pod comprehensive-stage3-winner -o wide
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
  kubectl delete pod comprehensive-stage3-winner 2>/dev/null || true
  kubectl apply -f 99.comprehensive-stage3-winner.yaml
  kubectl get pod comprehensive-stage3-winner -o wide
```

## Key Takeaways

1. **Scenario 1**: No taints → w1-k8s wins (180 points: zone-a + ssd)
2. **Scenario 2**: w1-k8s tainted → w2-k8s wins (130 points: zone-a + hdd, highest remaining)
3. **Scenario 3**: Both w1-k8s and w2-k8s tainted → w3-k8s wins (80 points: zone-b + ssd, only matches ssd)
4. **Stage 3 scoring drives winner selection** when Stage 2 leaves multiple candidates
5. **NoSchedule taints filter nodes in Stage 2**, forcing scheduler to pick next best score

## Cleanup

```bash
# Remove demo taints
./taint-node.sh
# Select each tainted node and choose "Remove"

# Delete test pod
kubectl delete pod comprehensive-stage3-winner
```
