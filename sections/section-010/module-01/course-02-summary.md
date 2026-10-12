---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Summary

Roles define API permissions and bindings grant them to subjects. Namespace scope, API group, resource and verb determine the action being allowed. RoleBindings and ClusterRoleBindings provide different grant scopes.

Applicable RBAC grants combine, and indirect consequences can make apparently simple permissions sensitive. Least privilege requires examining every effective grant and the resources the identity can use to reach other authority.

You can now justify a narrow grant using the exact resource, action and namespace. A role name alone neither proves least privilege nor describes all effective permissions.
