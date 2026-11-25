# Summary

Role Based Access Control (RBAC) is the authorization mode that decides which identities may perform which actions in the Kubernetes API. The API server denies every request that no rule allows. A rule names API groups, resources, verbs and optionally resource names. An identity receives a rule through a binding.

A Role and a RoleBinding work inside one namespace. A ClusterRole is a reusable definition, and the binding decides its reach. A RoleBinding limits it to the namespace of the binding. A ClusterRoleBinding extends it to every namespace and to cluster-scoped resources.

The `roleRef` of a binding cannot change after the binding exists. A ServiceAccount subject must always carry its namespace. The user name of a ServiceAccount is `system:serviceaccount:<namespace>:<name>`.

Permissions only add up. The effective access of an identity is the union of every rule in every binding that names it, one of its groups, or a group it belongs to automatically. So removing one grant removes access only when no other grant allows the same action. The API server also stops an identity from creating a Role or binding that is larger than the permissions it holds, unless the identity has the verb `escalate` or `bind`.

Some permissions give more than their name says. Reading Secrets, creating Pods, running commands in Pods, requesting ServiceAccount tokens, and the verbs `escalate`, `bind` and `impersonate` all give indirect or broad authority. `kubectl auth can-i`, with `--as` and with `--list`, shows what an identity can do. `kubectl get rolebindings,clusterrolebindings -o wide` shows who holds a grant.

Key facts to remember:

- RoleBinding plus ClusterRole gives access in one namespace only.
- There is no deny rule in RBAC.
- `view` does not include Secrets; `edit` and `admin` do.
- `kubectl auth can-i` without `--as` answers for your own identity.

<!-- astrona:playground:destroy -->
