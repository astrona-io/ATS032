---
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Grant Namespace Pod Read Access

Allow about 6 minutes for the tasks.

This lab runs in its own kind cluster. Connect to it first:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-010-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-010-01-01" || exit 1
```

The `shuttle` workload in `starfleet-032-010-01-01` must read the Pods in its own namespace and do nothing else. A ServiceAccount is the identity a Pod uses when it calls the Kubernetes API (Application Programming Interface). The ServiceAccount `shuttle` exists and has no grant yet. The namespace `outpost-032-010-01-01` also exists.

1. In `starfleet-032-010-01-01`, create a Role named `pod-reader` that allows exactly `get`, `list` and `watch` on Pods (the core API group) and nothing else.
2. In the same namespace, create a RoleBinding named `shuttle-pod-reader` that references the Role `pod-reader` and names only the ServiceAccount `shuttle` of `starfleet-032-010-01-01`.
3. Give `shuttle` no other grant. No other RoleBinding or ClusterRoleBinding may name `shuttle`, so it can still not create or delete Pods, read Secrets, read Pods in `outpost-032-010-01-01` or list nodes.
