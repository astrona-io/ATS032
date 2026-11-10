---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Rewrite A Broad Grant As Least Privilege

Solve this question on: `terminal`

The `scout` workload in `starfleet-032-010-02-01` has more access than its job needs, and the security team asked for a narrow grant before the next review.

## Objective

Replace a cluster-wide ClusterRoleBinding with a namespaced Role and RoleBinding, and prove with `kubectl auth can-i` that the needed actions work and the rest are denied.

## Starting state

The `starfleet-032-010-02-01` and `outpost-032-010-02-01` namespaces exist. The ServiceAccounts `scout` and `shuttle` live in `starfleet-032-010-02-01`. A ServiceAccount identifies a workload when it calls the Kubernetes application programming interface (API). The `scout` workload reads Pods in `outpost-032-010-02-01` and updates one ConfigMap named `scout-report` there. Today it holds the built-in `edit` ClusterRole in every namespace through the ClusterRoleBinding `scout-edit-everywhere`. Other grants exist that must keep working: `shuttle` reads ConfigMaps in `outpost-032-010-02-01`, and the group `starfleet-crew` has the `view` ClusterRole in `outpost-032-010-02-01`.

Use a host shell with this lab's private kubeconfig. A kubeconfig contains the cluster address and credentials used by kubectl, the Kubernetes command-line tool. The lab has a separate kind cluster from the module playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-010-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-010-02-01" || exit 1
```

Keep this connection selected for every command below.

Allow 6–8 minutes for task work. Cluster startup adds time.

## Tasks

1. Create the Role `scout-operator` in `outpost-032-010-02-01` with exactly two rules: `get`, `list` and `watch` on core Pods, and `get`, `update` and `patch` on the core ConfigMap named `scout-report` (use `resourceNames`).
2. Create the RoleBinding `scout-operator` in `outpost-032-010-02-01` that binds only the ServiceAccount `scout` in `starfleet-032-010-02-01` to that Role.
3. Delete the ClusterRoleBinding `scout-edit-everywhere`. Then prove with `kubectl auth can-i` that `scout` cannot read Secrets, create ConfigMaps, read another ConfigMap, delete Pods, read Pods in `starfleet-032-010-02-01` or read nodes.

## Constraints

- Add the new grant before you remove the old one, so the workload is never without access.
- No other binding may name `scout`.
- Do not remove the grants of `shuttle` or `starfleet-crew`.

## How the answer is checked

The grader runs three checks. The first checks the two rules of the Role `scout-operator`. The second checks that the RoleBinding `scout-operator` references that Role and only `scout`, and that `scout` can read Pods and get, update and patch `scout-report` in `outpost-032-010-02-01`. The third checks that the ClusterRoleBinding `scout-edit-everywhere` is gone, that no other binding names `scout`, and that every action in task 3 is denied. Every check also confirms that `shuttle` can still list ConfigMaps in `outpost-032-010-02-01` and that the group `starfleet-crew` can still list Pods there.

Hint: `kubectl auth can-i --list -n outpost-032-010-02-01 --as=system:serviceaccount:starfleet-032-010-02-01:scout` shows everything `scout` may do in that namespace.
