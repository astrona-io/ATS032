---
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Rewrite A Broad Grant As Least Privilege

Allow about 12 minutes for the tasks.

This lab runs in its own kind cluster. Connect to it first:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-010-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-010-02-01" || exit 1
```

The `scout` workload has far more access than its job needs. The ServiceAccount `scout` lives in `starfleet-032-010-02-01`. Its job is to read Pods in `outpost-032-010-02-01` and to update one ConfigMap there, `scout-report`. Today the ClusterRoleBinding `scout-edit-everywhere` gives it the built-in ClusterRole `edit` in every namespace, and it may hold other grants too. Two other grants in `outpost-032-010-02-01` must keep working: `shuttle` reads ConfigMaps, and the group `starfleet-crew` holds the ClusterRole `view`.

1. In `outpost-032-010-02-01`, create a Role named `scout-operator` with exactly these permissions: `get`, `list` and `watch` on Pods, and `get`, `update` and `patch` on the ConfigMap named `scout-report` only (use `resourceNames`). Both resources are in the core API group.
2. In `outpost-032-010-02-01`, create a RoleBinding named `scout-operator` that gives the Role `scout-operator` to the ServiceAccount `scout` of `starfleet-032-010-02-01` and to no other subject.
3. Remove every other grant of `scout`, so that `scout-operator` is the only binding in the cluster that names `scout`, in any form. After this, `scout` must hold nothing else in `outpost-032-010-02-01`, nothing in `starfleet-032-010-02-01`, and it must not list nodes.
4. Do not remove the grants of `shuttle` and `starfleet-crew`.
