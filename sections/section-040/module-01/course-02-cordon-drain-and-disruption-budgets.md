---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Cordon, Drain And Disruption Budgets

A node cannot be upgraded while workloads run on it. The kubelet restarts, and in some upgrades the node restarts. This part shows how to stop new Pods from landing on a node, move the existing ones elsewhere, and keep the application available while you do it. A PodDisruptionBudget sets the limit that the drain must respect.

## Cordon, drain and uncordon

Three commands handle a node during maintenance.

- `kubectl cordon <node>` marks the node unschedulable. The scheduler places no new Pods on it. Running Pods stay.
- `kubectl drain <node>` cordons the node and then evicts its Pods. An eviction asks the API server to delete a Pod in a way that respects PodDisruptionBudgets. A Pod owned by a controller, such as a Deployment, is recreated on another node.
- `kubectl uncordon <node>` makes the node schedulable again. Pods that were moved away do not return on their own.

A drain stops for Pods that cannot be moved. It refuses to drain a node with DaemonSet Pods unless you add `--ignore-daemonsets`, because a DaemonSet controller would put the Pod back at once. It refuses Pods that no controller owns, called bare Pods, because nothing would recreate them. It refuses Pods with local `emptyDir` data unless you add `--delete-emptydir-data`. The `--force` flag deletes bare Pods and they are lost.

## The PodDisruptionBudget

A **PodDisruptionBudget** (PDB) sets how many Pods of an application may be unavailable during a voluntary disruption, such as a drain. It uses a label selector and one of two fields.

- `minAvailable` is the number or percentage of Pods that must stay available.
- `maxUnavailable` is the number or percentage of Pods that may be down at once.

When a drain evicts a Pod, the API server checks the budget. If the eviction would break it, the API server refuses with a message that mentions the disruption budget, and `kubectl drain` retries until the budget allows the eviction or the timeout ends. A PDB protects only against voluntary disruptions. It does not stop a node crash.

A budget can also block a drain forever. A PDB with `minAvailable: 2` on a Deployment of two replicas allows no eviction at all, and so the drain never completes.

## Drain a worker

<!-- astrona:playground:renew -->

The Deployment `probe` has two replicas. Save this as `pdb-probe-budget.yaml`. It allows one replica to be down at a time:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: probe-budget
  namespace: starfleet
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app: probe
```

Apply it and check where the Pods run:

```sh
kubectl apply -f pdb-probe-budget.yaml
kubectl -n starfleet get pdb probe-budget
kubectl get pods -A -o wide --field-selector spec.nodeName=astro-ats-032-playground-040-01-worker
```

The budget shows `ALLOWED DISRUPTIONS` of `1` when both replicas are ready. The Pod list shows what runs on the first worker. The clients `shuttle` and `drifter` run on the second worker, so the drain of the first worker does not meet a bare Pod. Draining the second worker would be refused, because both clients are bare Pods.

Drain the first worker. The `--ignore-daemonsets` flag lets the drain skip the DaemonSet Pods of the network plugin and `kube-proxy`. The timeout bounds the wait:

```sh
kubectl drain astro-ats-032-playground-040-01-worker --ignore-daemonsets --timeout=120s
```

The command prints a line for each Pod it evicts and ends with a message that the node is drained. If a probe Pod runs on that node, the Pod is recreated on another node. Check that the application still has two ready replicas and that the node is unschedulable:

```sh
kubectl -n starfleet get pods -l app=probe -o wide
kubectl get nodes
```

The first worker is shown with the status `Ready,SchedulingDisabled`. Both probe Pods run on schedulable nodes. This is the state in which you would upgrade the kubelet of that node. When the maintenance is done, return the node:

```sh
kubectl uncordon astro-ats-032-playground-040-01-worker
kubectl get nodes
```

The node loses `SchedulingDisabled`. The Pods that moved stay where they are, and new Pods may now use the node again. Remove the budget with `kubectl -n starfleet delete pdb probe-budget` if you do not need it.

## What a budget cannot do

A drain with a PDB protects availability only if the application has enough replicas. One replica with `minAvailable: 1` cannot be evicted, and one replica with no PDB is down during the move. A Deployment with replicas spread across nodes, together with a PDB, is what makes a rolling node upgrade safe. Pods that mount a volume that can attach to only one node need extra time to move.

You can now take a node out of service and return it without breaking the application. Next is what happens inside the node and the control plane during the version upgrade itself.

## Common pitfalls

> [!WARNING]
> - **Draining without `--ignore-daemonsets`.** The drain stops on DaemonSet Pods.
> - **Using `--force` to get past a bare Pod.** The Pod is deleted and nothing recreates it.
> - **A PDB that allows no disruption.** The drain waits forever. Use `--timeout`, and check `ALLOWED DISRUPTIONS`.
> - **Forgetting `kubectl uncordon`.** The node stays unschedulable after the maintenance.
> - **Expecting a PDB to protect against a node failure.** It applies only to evictions.
