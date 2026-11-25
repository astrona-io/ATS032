# Audit ServiceAccount Use And Tokens

Setting up ServiceAccounts correctly is only half of the work. A ServiceAccount is the Kubernetes identity that a pod uses when it sends requests to the API server. Clusters change over time: new workloads arrive, someone adds a quick fix, and an old token Secret stays behind.

A security review has to look at the whole cluster and answer three questions. Which pod uses which ServiceAccount? Who can act as each ServiceAccount? Which tokens exist, and how long do they live? This module gives you the commands that answer these questions, and then fixes what they find.

Keep one sentence in mind: **a ServiceAccount is only as safe as the weakest of its pods, its grants and its tokens.** You list pods with their accounts and their automount settings. You follow bindings, including bindings to groups, to the accounts they reach. You find long-lived token Secrets and long projected tokens, and you test a token against the API server.

## What you will learn

After this module, you can:

- list every pod with its ServiceAccount and its automount setting, and tell which pods hold a token;
- find the RoleBindings and ClusterRoleBindings that reach a ServiceAccount, directly or through a ServiceAccount group;
- check the effective permissions of a ServiceAccount with `kubectl auth can-i --list`;
- list the long-lived token Secrets and the ServiceAccount that each one belongs to;
- read the lifetime and the audience of a projected token, and test a token through a separate kubeconfig user.

## How the module is laid out

You start with **Find Which Pods Use Which ServiceAccount**, which builds the inventory of accounts and token mount settings. **Audit Grants That Reach ServiceAccounts** then follows direct bindings and group bindings, and checks what each account may really do. **Audit Tokens: Secrets, Lifetimes And Audience** closes the module. It finds legacy token Secrets, reads the settings of projected tokens, and shows that the API server refuses a token with another audience.

A graded lab follows the part on grants, and another follows the part on tokens, so you can practise each skill right away.

## Before you start

You should know the Kubernetes basics and the basics of RBAC (role-based access control): Role, ClusterRole, RoleBinding and ClusterRoleBinding. You should also know that a pod receives a ServiceAccount token unless token mounting is turned off.

The commands run against a playground cluster. Your terminal must use the private kubeconfig of the playground. A kubeconfig is the file that holds the cluster address and the credentials for `kubectl`. Run these two commands once in every new terminal:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-020-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-020-03" || exit 1
```

## Your playground

Your playground is a `kind` cluster that runs Kubernetes v1.35 with one control-plane node and one worker node. Your own credentials have the `cluster-admin` role. The cluster already holds these objects:

| Namespace | Object | What it is |
| --- | --- | --- |
| `starfleet` | `probe` Deployment, two pods, labels `app: probe` and `release: probe` | A small web server that listens on port 8080. It uses the `default` ServiceAccount |
| `starfleet` | `probe` Service | Port 80, forwards to port 8080 of the `probe` pods |
| `starfleet` | `probe-code` ConfigMap | The Python code that the `probe` pods run |
| `starfleet` | `shuttle` pod, label `app: shuttle` | A client pod that uses the `default` ServiceAccount |
| `outpost` | `drifter` pod, label `app: drifter` | A client pod that uses the `default` ServiceAccount |
| `outpost` | `ledger` ServiceAccount | An account with no automount setting of its own |
| `outpost` | `archive` ServiceAccount | An account with `automountServiceAccountToken: false` |
| `outpost` | `ledger-client` pod | Uses `ledger`, turns off automounting, and mounts its own projected token with a lifetime of 86400 seconds at `/var/run/tokens` |
| `outpost` | `archive-reader` pod | Uses `archive` and sets no automount field of its own |
| `outpost` | `ledger-legacy-token` Secret | A Secret of type `kubernetes.io/service-account-token` for `ledger` |
| `outpost` | `outpost-all-view` RoleBinding | Gives the `view` ClusterRole to the group `system:serviceaccounts:outpost` |
| cluster-wide | `ledger-edit` ClusterRoleBinding | Gives the `edit` ClusterRole to the ServiceAccount `outpost/ledger` |

Start your playground now and keep it running while you read:

<!-- astrona:playground -->
