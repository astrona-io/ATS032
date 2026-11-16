---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Give Each Workload Its Own Least-Privilege ServiceAccount

Solve this question on: `terminal`

Move one workload to a dedicated ServiceAccount without a token, create a ServiceAccount that has one narrow grant, and remove the grant from the default account.

## Starting state

The `starfleet-032-020-02-01` namespace runs the Deployment `probe` (two replicas) and the pod `shuttle`. Both use the `default` ServiceAccount. Someone fixed an old error by creating the Role `pod-access` and binding it to the `default` ServiceAccount of `starfleet-032-020-02-01` with the RoleBinding `default-pod-access`, so every pod of the namespace can read pods. The `outpost-032-020-02-01` namespace runs the pod `drifter`.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-020-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-020-02-01" || exit 1
```

Keep this connection selected. Every script supplied by the lab refuses a different context.

Allow 8–10 minutes for task work. Cluster startup adds time.

## Tasks

1. Create the ServiceAccount `probe` with `automountServiceAccountToken: false`. Change the Deployment `probe` to use it and wait until the rollout is complete with two ready replicas. The `probe` pods must have no token directory.
2. Create the ServiceAccount `pod-lister`, the Role `pod-lister` and the RoleBinding `pod-lister`. The Role has exactly one rule: the verbs `get` and `list` on `pods` in the core API group. The binding gives the Role to the ServiceAccount `pod-lister` only.
3. Run a new Pod named `pod-lister` with the ServiceAccount `pod-lister`.
4. Remove the RoleBinding `default-pod-access`, and set `automountServiceAccountToken: false` on the `default` ServiceAccount of `starfleet-032-020-02-01`.

## Constraints

- Make every change in `starfleet-032-020-02-01`, and keep the namespace, workload names and unrelated components as they are.
- Do not change the Role `pod-access`; only the binding must go.

## How the answer is checked

The grader runs four checks, one per task. The first checks the ServiceAccount `probe`, the Deployment's ServiceAccount and that the `probe` pods have no token directory. The second checks the ServiceAccount, Role and RoleBinding `pod-lister`, and asks the API server that `pod-lister` can get Pods in `starfleet-032-020-02-01` but cannot delete them and cannot read Pods in `outpost-032-020-02-01`. The third checks that the Pod `pod-lister` runs as `pod-lister`. The fourth checks that `default-pod-access` is gone, that the `default` ServiceAccount mounts no token, and that it cannot get Pods. Wait for the rollout to finish before you submit.
