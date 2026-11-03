---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Give Each Workload Its Own Least-Privilege ServiceAccount

Move one workload to a dedicated ServiceAccount without a token, create a ServiceAccount that has one narrow grant, and remove the grant from the default account.

## Starting state

The `starfleet` namespace runs the Deployment `probe` (two replicas) and the pod `shuttle`. Both use the `default` ServiceAccount. Someone fixed an old error by creating the Role `pod-access` and binding it to the `default` ServiceAccount of `starfleet` with the RoleBinding `default-pod-access`, so every pod of the namespace can read pods. The `outpost` namespace runs the pod `drifter`.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-020-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-020-02-01" || exit 1
```

Keep this connection selected. Every script supplied by the lab refuses a different context.

## Required result

Make these changes in the `starfleet` namespace and keep the namespace, workload names and unrelated components as they are.

1. Create the ServiceAccount `probe` with `automountServiceAccountToken: false`. Change the Deployment `probe` to use it and wait until the rollout is complete with two ready replicas. The `probe` pods must have no token directory.
2. Create the ServiceAccount `pod-lister`, the Role `pod-lister` and the RoleBinding `pod-lister`. The Role has exactly one rule: the verbs `get` and `list` on `pods` in the core API group. The binding gives the Role to the ServiceAccount `pod-lister` only. Run a new pod named `pod-lister` with that ServiceAccount.
3. Remove the RoleBinding `default-pod-access`, and set `automountServiceAccountToken: false` on the `default` ServiceAccount of `starfleet`.

When you finish, `pod-lister` can get pods in `starfleet` but cannot delete pods there and cannot read pods in `outpost`, and the `default` ServiceAccount of `starfleet` cannot get pods.

## Verify The Result

The grader checks the object fields and asks the API server what each ServiceAccount may do. Wait for the rollout to finish before you submit. Do not change the Role `pod-access`; only the binding must go.
