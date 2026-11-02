---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Minimize Exposure With Role Based Access Control

Role Based Access Control (RBAC) decides what each identity may do in the cluster, and there is no deny rule: access is the union of every grant. This section builds Roles and bindings, shows how a binding decides the reach of a ClusterRole, explains the check that stops an identity from granting more than it holds, and shows how to list who can do what.

The section has one module. Read the landing page, then the parts in order, and use the playground next to the text. The lab follows the part it practises, and the summary closes the module. A ten-question knowledge check follows the summary.

## Learning Outcomes

- Build a Role and a RoleBinding and prove their limits with kubectl auth can-i.
- Explain how a RoleBinding or ClusterRoleBinding decides the reach of a ClusterRole.
- Explain escalation prevention and the verbs escalate, bind and impersonate.
- Find all bindings that keep an action alive and audit the access of an identity.
