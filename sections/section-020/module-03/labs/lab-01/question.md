---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Remove ServiceAccount Findings From A Namespace

Solve this question on: `terminal`

Remove the over-broad grants, the long-lived token Secret and the long projected token from a namespace, and keep the one permission the workload needs.

## Starting state

The `outpost-032-020-03-01` namespace has the ServiceAccounts `ledger` and `archive`, the pods `ledger-client` and `archive-reader`, and the pod `drifter`. A review found four problems. The ClusterRoleBinding `ledger-edit` gives the `edit` ClusterRole to `ledger`. The RoleBinding `outpost-all-view` gives the `view` ClusterRole to the group `system:serviceaccounts:outpost-032-020-03-01`. The Secret `ledger-legacy-token` is a long-lived token for `ledger`. The pod `ledger-client` mounts a projected token that lives 86400 seconds.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-020-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-020-03-01" || exit 1
```

Keep this connection selected. Every script supplied by the lab refuses a different context.

Allow 8–10 minutes for task work. Cluster startup adds time.

## Tasks

1. Delete the Secret `ledger-legacy-token`.
2. Delete the ClusterRoleBinding `ledger-edit` and the RoleBinding `outpost-all-view`.
3. The `ledger` account must still read ConfigMaps in `outpost-032-020-03-01`. Create the Role `config-reader` with exactly one rule (verbs `get` and `list` on `configmaps` in the core API group) and the RoleBinding `config-reader` that gives it to the ServiceAccount `ledger` only.
4. Recreate the Pod `ledger-client` with the same ServiceAccount, `automountServiceAccountToken: false` and one projected volume named `ledger-token` with the path `token` and a token lifetime of 3600 seconds.

## Constraints

- Keep the names of the Pods, ServiceAccounts and namespace.
- Do not change the Pod `archive-reader`.

## How the answer is checked

The grader runs four checks, one per task. The first checks that the Secret `ledger-legacy-token` is gone. The second checks that `ledger-edit` and `outpost-all-view` are gone, and asks the API server that `ledger` cannot delete ConfigMaps or read Secrets and that `archive` cannot list Pods in `outpost-032-020-03-01`. The third checks the Role and RoleBinding `config-reader` and that `ledger` can get ConfigMaps. The fourth checks the projected token of `ledger-client`. Every check also confirms that `archive-reader` is unchanged. Wait for the new Pod to be ready before you submit.
