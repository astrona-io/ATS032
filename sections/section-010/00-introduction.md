# Minimize Exposure With Role Based Access Control

Picture a ServiceAccount that a team created for one small job. Months later, it can still delete Secrets in every namespace, because someone once gave it a broad role to make an error go away. Nobody noticed, and nothing in the cluster warns you.

Role Based Access Control (RBAC) is the part of Kubernetes that decides what each identity may do. It has no deny rule: the access of an identity is the sum of every grant it has. A grant that is too broad stays in place until someone finds it. In this section, you learn how to build narrow grants and how to audit and trim the grants that already exist.

## What you will learn

The section moves from building one grant to auditing a whole cluster:

- **Minimize Exposure With Role Based Access Control.** Roles and bindings, how a binding decides how far a ClusterRole reaches, how Kubernetes stops a user from granting more than they have, the dangerous verbs, and a first look at auditing.
- **Audit And Narrow Effective Access.** Exact `kubectl auth can-i` questions, a search for every binding that reaches an identity, and the safe order for replacing a broad grant with a narrow one.
- **Subjects, Built-In Roles And Wildcards.** Users, groups and ServiceAccounts as subjects, the default and aggregated ClusterRoles, and how to remove wildcards from rules.

## How this section works

Each module has its own playground: a private `kind` cluster that runs Kubernetes v1.35. Start it from the first page of the module and keep it running while you read, because every page has commands to try.

When a page teaches a skill you can be graded on, a lab comes right after it. A lab gives you a short task in a fresh cluster and checks your result. Each module ends with a summary and a short knowledge check.

## By the end of this section

You will be able to:

- build a Role and a RoleBinding, and prove their limits with `kubectl auth can-i`;
- explain how a RoleBinding or a ClusterRoleBinding decides how far a ClusterRole reaches;
- explain escalation prevention and the verbs `escalate`, `bind` and `impersonate`;
- find every binding that keeps an action allowed, and audit the access of an identity;
- ask the authorizer about resource names, subresources, URLs and groups, and replace a broad grant with a narrow one in an order that causes no outage;
- write bindings with user, group and ServiceAccount subjects, and build an aggregated ClusterRole from labelled roles;
- find and remove wildcards from Roles, and test the result with allowed and denied actions.
