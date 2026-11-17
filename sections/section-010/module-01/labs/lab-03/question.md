---
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Revoke An Action That Several Bindings Grant

Allow about 8 minutes for the tasks.

This lab runs in its own kind cluster. Connect to it first:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-010-01-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-010-01-03" || exit 1
```

The `shuttle` workload must stop reading Pods in `outpost-032-010-01-03`, but it still needs the ConfigMaps there. The ServiceAccount `shuttle` lives in `starfleet-032-010-01-03`. More than one binding in `outpost-032-010-01-03` gives it Pod reads.

1. Make sure `shuttle` can no longer `get`, `list` or `watch` Pods in `outpost-032-010-01-03`.
2. Keep the RoleBinding `shuttle-configmap-reader` and the Role `configmap-reader` unchanged, so `shuttle` can still `get` and `list` ConfigMaps in `outpost-032-010-01-03`.
3. After your change, `shuttle` must hold no other permission in `outpost-032-010-01-03` than those ConfigMap reads.
