---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Harden ServiceAccounts Across Two Namespaces

Give each workload its own identity, remove the grants and tokens that a review found, and prove the result with allowed and denied permission checks.

## Starting state

The `starfleet` namespace runs the Deployment `probe` (two replicas) and the pod `shuttle`. Both use the `default` ServiceAccount, and the RoleBinding `default-pod-access` gives that account the Role `pod-access`, which reads pods. The `shuttle` pod must read pods in its own namespace. The `outpost` namespace runs the pod `drifter`, which never calls the API. The Secret `drifter-legacy-token` is a long-lived token, and the ClusterRoleBinding `outpost-view-all` gives the `view` ClusterRole to every ServiceAccount of `outpost` in all namespaces.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-020-capstone-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-020-capstone-01" || exit 1
```

Keep this connection selected. Every script supplied by the lab refuses a different context.

## Required result

Make these changes. Keep the names of the namespaces, Deployment and pods.

1. In `starfleet`, create the ServiceAccount `probe` with `automountServiceAccountToken: false` and move the Deployment `probe` to it. Wait for two ready replicas. The `probe` pods must have no token directory.
2. In `starfleet`, delete the RoleBinding `default-pod-access` and set `automountServiceAccountToken: false` on the `default` ServiceAccount. Do not delete the Role `pod-access`.
3. In `starfleet`, create the ServiceAccount `shuttle-reader` (token mounting off), the Role `shuttle-reader` and the RoleBinding `shuttle-reader`. The Role has exactly one rule: the verbs `get` and `list` on `pods` in the core API group. Recreate the pod `shuttle` with this ServiceAccount, `automountServiceAccountToken: false` in the pod and one projected volume named `api-token` with the path `token` and a token lifetime of 900 seconds, mounted at `/var/run/tokens`.
4. In `outpost`, delete the Secret `drifter-legacy-token` and the ClusterRoleBinding `outpost-view-all`.
5. In `outpost`, recreate the pod `drifter` with `automountServiceAccountToken: false` and no other change.

When you finish, `shuttle-reader` can get pods in `starfleet` but cannot delete pods or read Secrets there, the `default` accounts of `starfleet` and `outpost` cannot read pods in `starfleet`, and `shuttle` can read its own token file.

## Verify The Result

The grader checks the object fields, asks the API server what each ServiceAccount may do, looks for the token files inside the containers and checks that the removed objects are gone. Wait for the pods to be ready before you submit.
