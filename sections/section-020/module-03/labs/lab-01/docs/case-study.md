---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Starting Environment

The `outpost-032-020-03-01` namespace has the ServiceAccounts `ledger` and `archive`, the pods `ledger-client` and `archive-reader`, and the pod `drifter`. A review found four problems. The ClusterRoleBinding `ledger-edit` gives the `edit` ClusterRole to `ledger`. The RoleBinding `outpost-all-view` gives the `view` ClusterRole to the group `system:serviceaccounts:outpost-032-020-03-01`. The Secret `ledger-legacy-token` is a long-lived token for `ledger`. The pod `ledger-client` mounts a projected token that lives 86400 seconds.

Remove the over-broad grants, the long-lived token Secret and the long projected token from a namespace, and keep the one permission the workload needs.
