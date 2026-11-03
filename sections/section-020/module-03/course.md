---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Audit ServiceAccount Use And Tokens

Setting up ServiceAccounts correctly is only half of the work. Clusters change: new workloads arrive, someone adds a quick fix, and an old token Secret stays behind. A security review has to look at the whole cluster and answer three questions. Which pod uses which ServiceAccount, who can act as each ServiceAccount, and which tokens exist and how long they live. This module gives you the commands that answer those questions and then fixes what they find.

Keep one sentence in mind for this module: **a ServiceAccount is only as safe as the weakest of its pods, its grants and its tokens.** You will list pods with their accounts and automount settings, follow bindings (including bindings to groups) to the accounts they reach, find long-lived token Secrets and long projected tokens, and test a token against the API server.

The module has three parts. **Find Which Pods Use Which ServiceAccount** builds the inventory of accounts and mount settings. **Audit Grants That Reach ServiceAccounts** follows direct and group bindings and checks effective permissions. **Audit Tokens: Secrets, Lifetimes And Audience** finds legacy token Secrets, reads projected token settings and shows that a token with another audience is refused by the API server.

## Learning objectives

After this module you can:

- List every pod with its ServiceAccount and its automount setting, and tell which pods hold a token.
- Find RoleBindings and ClusterRoleBindings that reach a ServiceAccount directly or through a ServiceAccount group.
- Check the effective permissions of a ServiceAccount with `kubectl auth can-i --list`.
- List long-lived token Secrets and the ServiceAccount that each belongs to.
- Read the lifetime and audience of a projected token and test a token with `kubectl --token`.

## Before you start

You need Kubernetes basics, RBAC basics (Role, ClusterRole, RoleBinding, ClusterRoleBinding) and the idea that a pod receives a ServiceAccount token unless mounting is turned off.

The commands run against a playground cluster. Your terminal must use the playground's private kubeconfig, the file that holds the cluster address and credentials for `kubectl`. Run these two commands once in every new terminal:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-020-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-020-03" || exit 1
```

The playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and one worker node. Your own credentials have the `cluster-admin` role. The cluster starts with this content:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The Deployment `probe` with two replicas, a Service `probe` and the pod `shuttle`. All of them use the `default` ServiceAccount |
| `outpost` | The pods `drifter`, `ledger-client` and `archive-reader`. The ServiceAccounts `ledger` and `archive`. The Secret `ledger-legacy-token`, the ClusterRoleBinding `ledger-edit` and the RoleBinding `outpost-all-view` |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
