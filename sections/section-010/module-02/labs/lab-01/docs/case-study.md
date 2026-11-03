---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Starting Environment

The `starfleet` and `outpost` namespaces exist. The ServiceAccounts `scout` and `shuttle` live in `starfleet`. A ServiceAccount identifies a workload when it calls the Kubernetes application programming interface (API). The `scout` workload reads Pods in `outpost` and updates one ConfigMap named `scout-report` there. Today it holds the built-in `edit` ClusterRole in every namespace through the ClusterRoleBinding `scout-edit-everywhere`. Other grants exist that must keep working: `shuttle` reads ConfigMaps in `outpost`, and the group `starfleet-crew` has the `view` ClusterRole in `outpost`.

Replace the cluster-wide grant of `scout` with a least-privilege grant in `outpost`. Create Role `scout-operator` in `outpost` with exactly two rules: `get`, `list` and `watch` on core Pods, and `get`, `update` and `patch` on the core ConfigMap named `scout-report` (use `resourceNames`). Create RoleBinding `scout-operator` in `outpost` that binds only the ServiceAccount `scout` in `starfleet` to that Role. Delete the ClusterRoleBinding `scout-edit-everywhere`. No other binding may name `scout`. Reading Secrets, creating ConfigMaps, reading another ConfigMap, deleting Pods, reading Pods in `starfleet` and reading nodes must be denied. Do not remove the grants of `shuttle` or `starfleet-crew`.
