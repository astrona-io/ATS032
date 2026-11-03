---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Summary

An access review starts with exact questions. `kubectl auth can-i` sends an access review request to the API server, which runs its real authorization chain. The question can name a verb, a resource, a resource name, a subresource, a non-resource URL and a namespace, and `--as` with `--as-group` tests an identity as a member of a group. The answer covers authorization only: it does not run admission and does not check that an object exists.

An identity answers to several names. A ServiceAccount has its own user name, the group `system:serviceaccounts`, the group of its namespace and the group `system:authenticated`. A binding to any of these names reaches the identity. Because RBAC has no deny rule, a review lists every RoleBinding and ClusterRoleBinding with its role and subjects, searches them for the identity and for the broad groups, and reads the rules behind each match. The gap between those rules and the real need is the exposure.

The fix follows a fixed order. Decide what the identity needs, add a narrow Role and binding in the namespace of the need, test the allowed actions, delete the broad binding, and test the denied actions. Delete the binding and never the built-in role. Subresources such as `pods/log` need their own entry. The field `resourceNames` limits a rule to named objects, but it cannot limit `create`, and it limits `list` and `watch` only when the request selects the object by name.

Key facts to remember:

- Effective access is the union of every rule in every binding that names the identity or one of its groups.
- A ClusterRoleBinding reaches every namespace, so search it as well as RoleBindings.
- Add the narrow grant before you remove the broad one.
- `resourceNames` does not apply to `create`.

<!-- astrona:playground:destroy -->
