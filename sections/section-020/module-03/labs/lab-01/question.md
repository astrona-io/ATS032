---
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions
  on newly created ones
---
# Remove Over-Broad ServiceAccount Bindings

Allow about 10 minutes for the tasks.

An audit of the `outpost` namespace found that its ServiceAccounts can do far more than their workloads need. The `ledger` application only reads ConfigMaps in its own namespace, and the `archive` job does not call the Kubernetes API at all. Fix their permissions.

## Connect to the lab

Use a shell on your own machine. The kubeconfig file holds the address and the credentials of this lab's cluster, and `kubectl` uses it.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-020-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-020-03-01" || exit 1
```

## Tasks

The ServiceAccounts `ledger` and `archive` live in the namespace `outpost-032-020-03-01`.

1. Find and remove every RoleBinding and ClusterRoleBinding that gives permissions to the group `system:serviceaccounts:outpost-032-020-03-01`. A new ServiceAccount in the namespace must get no permissions in `outpost-032-020-03-01` or in the namespace `default`.
2. Remove the cluster-wide permissions of `ledger`. Then give `ledger` permission to `get` and `list` ConfigMaps in `outpost-032-020-03-01`, and nothing else. It must have no permission in the namespace `default`.
3. `archive` must have no permissions at all: no binding may reach it, in `outpost-032-020-03-01` or in `default`.
4. Keep the ServiceAccounts `ledger` and `archive`.
