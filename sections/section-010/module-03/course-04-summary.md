---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Summary

A binding gives a role to subjects, and a subject is only a name. Kubernetes stores no User and no Group. Authentication produces a user name and groups, for example from the Common Name and Organization fields of a client certificate or from the claims of a token, and the RBAC authorizer compares them with the subjects of the bindings as text. A binding to a name that does not exist is valid and gives access to nobody, so every binding needs a test with `--as` and `--as-group`. A ServiceAccount subject always needs its namespace.

Kubernetes creates default ClusterRoles and bindings. `cluster-admin` is bound to `system:masters`, and a few `system:` roles are bound to `system:authenticated` to allow discovery and basic self-checks. The roles `view`, `edit` and `admin` are aggregated: a controller copies the rules of every ClusterRole that carries the matching label into them. The same mechanism builds custom roles from labelled parts. The rules of an aggregated role come only from the labelled roles, and any rule written by hand is overwritten.

A wildcard in `apiGroups`, `resources` or `verbs` matches everything, including subresources, verbs such as `escalate` and resources that do not exist yet. A Role with a star in all three lists gives the holder everything in its namespace, including the right to create bindings. The remedy is to find each wildcard, learn the real need, write explicit lists with names taken from `kubectl api-resources`, apply the Role in place so the binding keeps working, and test both the allowed and the denied actions.

Key facts to remember:

- RBAC does not check that users and groups exist.
- Aggregated ClusterRoles get their rules from labelled roles.
- A wildcard also matches subresources and future resources.
- Replace a Role in place instead of deleting it, so its bindings keep a target.

<!-- astrona:playground:destroy -->
