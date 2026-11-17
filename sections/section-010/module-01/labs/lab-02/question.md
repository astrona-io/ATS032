---
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Reuse A ClusterRole In One Namespace And Delegate Role Management

Allow about 8 minutes for the tasks.

This lab runs in its own kind cluster. Connect to it first:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-010-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-010-01-02" || exit 1
```

The `shuttle` workload must read the ordinary objects in `outpost-032-010-01-02` and manage the access rules of that namespace, without the power to grant itself more. The ServiceAccount `shuttle` lives in `starfleet-032-010-01-02` and has no grant yet.

1. In `outpost-032-010-01-02`, create a RoleBinding named `shuttle-view` that gives the built-in ClusterRole `view` to the ServiceAccount `shuttle` of `starfleet-032-010-01-02`, and to no other subject. Do not create a ClusterRoleBinding for `shuttle`: it must get no access in `starfleet-032-010-01-02` or in any other namespace.
2. In `outpost-032-010-01-02`, create a Role named `role-manager` that allows exactly `create`, `get` and `list` on `roles` and `rolebindings` in the API group `rbac.authorization.k8s.io`, and nothing else.
3. In `outpost-032-010-01-02`, create a RoleBinding named `shuttle-role-manager` that gives the Role `role-manager` to the ServiceAccount `shuttle` only.
4. `shuttle` must not hold the verbs `escalate` or `bind`, so it can still not create a Role that reads Secrets.
