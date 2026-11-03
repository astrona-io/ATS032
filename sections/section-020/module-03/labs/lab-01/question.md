---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Remove ServiceAccount Findings From A Namespace

Remove the over-broad grants, the long-lived token Secret and the long projected token from a namespace, and keep the one permission the workload needs.

## Starting state

The `outpost` namespace has the ServiceAccounts `ledger` and `archive`, the pods `ledger-client` and `archive-reader`, and the pod `drifter`. A review found four problems. The ClusterRoleBinding `ledger-edit` gives the `edit` ClusterRole to `ledger`. The RoleBinding `outpost-all-view` gives the `view` ClusterRole to the group `system:serviceaccounts:outpost`. The Secret `ledger-legacy-token` is a long-lived token for `ledger`. The pod `ledger-client` mounts a projected token that lives 86400 seconds.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-020-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-020-03-01" || exit 1
```

Keep this connection selected. Every script supplied by the lab refuses a different context.

## Required result

Fix the findings and keep the names of the pods, ServiceAccounts and namespace.

1. Delete the Secret `ledger-legacy-token`, the ClusterRoleBinding `ledger-edit` and the RoleBinding `outpost-all-view`.
2. The `ledger` account must still read ConfigMaps in `outpost`. Create the Role `config-reader` with exactly one rule (verbs `get` and `list` on `configmaps` in the core API group) and the RoleBinding `config-reader` that gives it to the ServiceAccount `ledger` only.
3. Recreate the pod `ledger-client` with the same ServiceAccount, `automountServiceAccountToken: false` and one projected volume named `ledger-token` with the path `token` and a token lifetime of 3600 seconds.

When you finish, `ledger` can get ConfigMaps in `outpost` but cannot delete them and cannot read Secrets, and the `archive` account cannot list pods in `outpost`.

## Verify The Result

The grader checks the object fields, asks the API server what each ServiceAccount may do, and checks that the three removed objects are gone. Wait for the new pod to be ready before you submit.
