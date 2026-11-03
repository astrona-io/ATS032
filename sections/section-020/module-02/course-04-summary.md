---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Summary

RBAC checks the identity of the caller, and for a pod that identity is its ServiceAccount. Workloads that share an account share every permission it holds, and a binding to the shared account does not say which workload needed it. The rule is one ServiceAccount for each workload, named after the workload. A workload that does not call the API gets an account with no grants and with token mounting turned off.

A ServiceAccount cannot be changed on a running pod, and neither can its volumes or its automount field. A Deployment moves to a new account through a rollout of its pod template, and a bare pod must be deleted and created again. An account name that does not exist stops the pods from starting.

A workload that does call the API gets a Role with only the verbs, resources and namespace it uses, and a RoleBinding that names that one account. Wildcards and cluster-wide bindings give more than the workload needs. The `roleRef` of a binding is fixed, and `resourceNames` limits `get`, `update` and `delete` but not `list` or `watch`. `kubectl auth can-i` with `--as` proves both the allowed and the denied actions without running the workload.

The `default` account exists in every namespace and is recreated if it is deleted. A new one has no grants, so the review looks for bindings that name it, directly or through a group, in Roles and in ClusterRoles. Removing the binding removes the grant, and patching the account with `automountServiceAccountToken: false` stops new pods from receiving a token. The patch is repeated for each namespace the team owns, and an admission policy or a provisioning step makes the rule hold for new namespaces and for pods that try to switch the mount back on.

Key facts to remember:

- One workload, one ServiceAccount, and only the grants that workload uses.
- A new ServiceAccount has no permissions; add them with a Role and a RoleBinding.
- Pods keep the account they were created with.
- Test an allowed action and a denied action with `kubectl auth can-i --as`.
- Patch `default` rather than deleting it, and never bind roles to it.

<!-- astrona:playground:destroy -->
