---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Subjects, Built-In Roles And Wildcards

Every RBAC grant has two sides: the rules that say what is allowed, and the subject that receives them. Mistakes on either side expose a cluster. A subject can be a user, a group or a ServiceAccount, and Kubernetes stores none of the first two. A role can be a built-in one that grows by itself, or a custom one with a wildcard that matches more than its author meant. Role Based Access Control (RBAC) is the authorization mode of the Kubernetes API server, and trimming subjects and wildcards is part of the Certified Kubernetes Security Specialist (CKS) exam.

Keep one sentence in mind for this module: **a subject is only a name that authentication produces, a built-in role is a set of rules that other roles can extend, and a wildcard matches things that do not exist yet, so name the subject exactly and write the rules out.** You will bind a user, a group and a ServiceAccount in one binding, build an aggregated ClusterRole that grows when a labelled role is added, and rewrite a wildcard Role without breaking the group that uses it.

The module has three parts. **Users, Groups And ServiceAccounts As Subjects** shows where the names in a binding come from, how a certificate becomes a user and its groups, and what happens when a name does not exist. **Built-In And Aggregated ClusterRoles** explains the roles Kubernetes creates, the groups they are bound to, and how an aggregated ClusterRole collects rules from labelled roles. **Remove Wildcards And Narrow Rules** shows what a wildcard grants, how to find one, and how to replace it with explicit lists.

## Learning objectives

After this module you can:

- Write a binding with a `User`, a `Group` and a `ServiceAccount` subject and say which fields each subject needs.
- Explain where user names and groups come from and why RBAC does not check that they exist.
- Name the built-in ClusterRoles and the built-in bindings to `system:masters` and `system:authenticated`.
- Build an aggregated ClusterRole with `aggregationRule` and explain why its `rules` field must stay empty.
- Explain what a wildcard in `apiGroups`, `resources` and `verbs` matches, and find wildcards in Roles.
- Replace a wildcard rule with explicit lists and prove the result with allowed and denied tests.

## Before you start

You need Kubernetes basics: pods, namespaces, YAML manifests, and the commands `kubectl get` and `kubectl apply`. You should know that a Role holds rules and that a binding gives a role to subjects. You do not need any earlier module.

The commands run against a playground cluster. Your terminal must use the playground's private kubeconfig, the file that holds the cluster address and credentials for `kubectl`. Run these two commands once in every new terminal:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-010-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-010-03" || exit 1
```

The playground is a single-node `kind` cluster running Kubernetes 1.35. Your own credentials in this cluster have the `cluster-admin` role, so you can create any RBAC object and act as other identities. The cluster starts with this content:

| Where | What is in it |
| --- | --- |
| Namespace `starfleet` | The ServiceAccount `probe` |
| Namespace `outpost` | The Role `crew-operator`, whose rule uses `*` for API groups, resources and verbs, and the RoleBinding `outpost-crew-operator` that gives it to the group `outpost-crew` |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
