---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Rewrite A Broad Grant As Least Privilege

The `scout` workload in `starfleet` has more access than its job needs, and the security team asked for a narrow grant before the next review.

## Objective

Replace a cluster-wide ClusterRoleBinding with a namespaced Role and RoleBinding, and prove with `kubectl auth can-i` that the needed actions work and the rest are denied.

## Starting state

The `starfleet` and `outpost` namespaces exist. The ServiceAccounts `scout` and `shuttle` live in `starfleet`. A ServiceAccount identifies a workload when it calls the Kubernetes application programming interface (API). The `scout` workload reads Pods in `outpost` and updates one ConfigMap named `scout-report` there. Today it holds the built-in `edit` ClusterRole in every namespace through the ClusterRoleBinding `scout-edit-everywhere`. Other grants exist that must keep working: `shuttle` reads ConfigMaps in `outpost`, and the group `starfleet-crew` has the `view` ClusterRole in `outpost`.

Use a host shell with this lab's private kubeconfig. A kubeconfig contains the cluster address and credentials used by kubectl, the Kubernetes command-line tool. The lab has a separate kind cluster from the module playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-010-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-010-02-01" || exit 1
```

Keep this connection selected for every command below.

## Required result

Replace the cluster-wide grant of `scout` with a least-privilege grant in `outpost`. Create Role `scout-operator` in `outpost` with exactly two rules: `get`, `list` and `watch` on core Pods, and `get`, `update` and `patch` on the core ConfigMap named `scout-report` (use `resourceNames`). Create RoleBinding `scout-operator` in `outpost` that binds only the ServiceAccount `scout` in `starfleet` to that Role. Delete the ClusterRoleBinding `scout-edit-everywhere`. No other binding may name `scout`. Reading Secrets, creating ConfigMaps, reading another ConfigMap, deleting Pods, reading Pods in `starfleet` and reading nodes must be denied. Do not remove the grants of `shuttle` or `starfleet-crew`.

## Verify the result

Inspect the required fields and observe the actual result. The grader checks the Role and the binding fields, searches every binding for the identity, and tests allowed and denied actions. Add the new grant before you remove the old one, so the workload is never without access.
