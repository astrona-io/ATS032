---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Summary

Role Based Access Control (RBAC) is the authorization mode that decides which identities may perform which actions in the Kubernetes API. The API server denies every request that no rule allows. A rule names API groups, resources, verbs and optionally resource names, and an identity receives it through a binding.

A Role and a RoleBinding work inside one namespace. A ClusterRole is a reusable definition, and the binding decides its reach: a RoleBinding limits it to its own namespace, and a ClusterRoleBinding extends it to every namespace and to cluster-scoped resources. The `roleRef` of a binding cannot change after creation. The ServiceAccount subject must always carry its namespace, and its user name is `system:serviceaccount:<namespace>:<name>`.

Permissions only add up. The effective access of an identity is the union of every rule in every binding that names it, its groups, or a group it belongs to automatically. Removing one grant removes access only when no other grant allows the same action. The API server also stops an identity from creating a Role or binding that is larger than the permissions it holds, unless it has the verbs `escalate` or `bind`.

Some permissions give more than their name says. Reading Secrets, creating Pods, running commands in Pods, requesting ServiceAccount tokens, and the verbs `escalate`, `bind` and `impersonate` all give indirect or broad authority. `kubectl auth can-i`, with `--as` and with `--list`, and `kubectl get rolebindings,clusterrolebindings -o wide` show what an identity can do and who holds a grant.

Key facts to remember:

- RoleBinding plus ClusterRole gives access in one namespace only.
- There is no deny rule in RBAC.
- `view` does not include Secrets; `edit` and `admin` do.
- `kubectl auth can-i` without `--as` answers for your own identity.

<!-- astrona:playground:destroy -->
