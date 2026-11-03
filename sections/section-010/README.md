---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Minimize Exposure With Role Based Access Control

Role Based Access Control (RBAC) decides what each identity may do in the cluster, and there is no deny rule: access is the union of every grant. A grant that is too broad stays in place until someone finds it, so this section teaches both sides of the work: how to build narrow grants, and how to audit and trim the grants that already exist.

## Learning Path

1. Minimize Exposure With Role Based Access Control: Roles and bindings, how a binding decides the reach of a ClusterRole, escalation prevention, dangerous verbs and a first look at auditing.
2. Audit And Narrow Effective Access: exact `kubectl auth can-i` questions, a search of every binding that reaches an identity, and the safe order for replacing a broad grant with a narrow one.
3. Subjects, Built-In Roles And Wildcards: users, groups and ServiceAccounts as subjects, the default and aggregated ClusterRoles, and the removal of wildcards from rules.
4. Capstone: remediate an RBAC review across three namespaces.

Each module ends with a summary and a ten-question knowledge check. The parts carry the hands-on steps. Each lab follows the part that practises its skill. The playground is a private `kind` cluster with Kubernetes v1.35; launch it from the landing page and keep it running while you read.

## Learning Outcomes

- Build a Role and a RoleBinding and prove their limits with kubectl auth can-i.
- Explain how a RoleBinding or ClusterRoleBinding decides the reach of a ClusterRole.
- Explain escalation prevention and the verbs escalate, bind and impersonate.
- Find all bindings that keep an action alive and audit the access of an identity.
- Ask the authorizer about resource names, subresources, URLs and groups, and replace a broad grant with a narrow one in an order that causes no outage.
- Write bindings with user, group and ServiceAccount subjects, and build an aggregated ClusterRole from labelled roles.
- Find and remove wildcards from Roles and test the result with allowed and denied actions.
