# Summary

An access review starts with exact questions. `kubectl auth can-i` sends an access review request to the API server, and the API server runs its real authorization chain. The question can name a verb, a resource, a resource name, a subresource, a non-resource URL and a namespace. The flags `--as` and `--as-group` test an identity as a member of a group.

The answer covers authorization only. The check does not run admission, and it does not check that an object exists. A subresource needs the `--subresource` flag, because a slash after the resource asks about an object name.

An identity answers to several names. A ServiceAccount has its own user name, the group `system:serviceaccounts`, the group of its namespace and the group `system:authenticated`. A binding to any of these names reaches the identity.

Because RBAC has no deny rule, a review lists every RoleBinding and ClusterRoleBinding with its role and subjects. It searches them for the identity and for the broad groups, and it reads the rules behind each match. The gap between those rules and the real need is the exposure.

The fix follows a fixed order. Decide what the identity needs, add a narrow Role and binding in the namespace of the need, and test the allowed actions. Then delete the broad binding and test the denied actions. Delete the binding, never the built-in role.

Subresources such as `pods/log` need their own entry in a rule. The field `resourceNames` limits a rule to named objects. It cannot limit `create`, and it limits `list` and `watch` only when the request selects the object by name.

Key facts to remember:

- Effective access is the union of every rule in every binding that names the identity or one of its groups.
- A ClusterRoleBinding reaches every namespace, so search it as well as RoleBindings.
- Add the narrow grant before you remove the broad one.
- `resourceNames` does not apply to `create`.

<!-- astrona:playground:destroy -->
