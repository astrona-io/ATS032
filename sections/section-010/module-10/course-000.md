# Minimize Exposure With Role Based Access Control

Every action in a Kubernetes cluster is a request to the Kubernetes API server. The API server denies every request that no rule allows. Role Based Access Control (RBAC) is the authorization mode that holds those rules. Each rule says which identity may perform which action on which resource, and in which namespace.

A cluster is only as exposed as the sum of these rules. If a workload holds more permissions than it needs, an attacker who takes over that workload holds them too. Reading and trimming RBAC rules is therefore one of the main hardening tasks for the Certified Kubernetes Security Specialist (CKS) exam.

Keep one sentence in mind for this module: **RBAC only adds permissions, so the effective access of an identity is the union of every Role and ClusterRole bound to it, and the only way to reduce exposure is to bind less.** You build a narrow grant for the `shuttle` ServiceAccount, reuse a ClusterRole through a RoleBinding, and meet the escalation check that stops an identity from granting more than it holds. You also remove a grant while another grant still allows the same action.

## What you will learn

After this module, you can:

- name the four RBAC objects and say which one limits a grant to a namespace;
- write a Role and a RoleBinding that give a ServiceAccount only the verbs, resources and namespace it needs;
- test an identity with `kubectl auth can-i` and `kubectl auth can-i --list`, using `--as` to act as a ServiceAccount;
- explain why RBAC has no deny rule and what that means when you remove a grant;
- name the verbs and resources that give indirect or broad authority, such as `list` on Secrets, `create` on Pods, `escalate`, `bind` and `impersonate`.

## How the module is laid out

You start with **Roles, Bindings And Scope**. It explains the four RBAC objects and the fields of a rule, and it shows how to build and test a grant in one namespace. **ClusterRoles, Reuse And Escalation Prevention** then binds the built-in `view` ClusterRole inside one namespace. It also shows why an identity cannot create a Role that is larger than its own permissions.

**Additive Grants, Dangerous Verbs And Auditing Access** closes the module. It shows that removing one binding does not remove access that a second binding gives. It lists the permissions that are riskier than they look, and it shows how to review who can do what.

A lab follows the parts, so you can practise each skill right away.

## Before you start

You should know the Kubernetes basics: pods, namespaces and YAML manifests. You should also be able to use `kubectl get` and `kubectl apply`. You do not need any earlier module.

The commands run against a playground cluster. Your terminal must use the private kubeconfig of the playground. A kubeconfig is the file that holds the cluster address and the credentials for `kubectl`. Run these two commands once in every new terminal:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-010-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-010-01" || exit 1
```

The first command points `kubectl` at the playground. The second command stops the terminal session if `kubectl` points at any other cluster.

## Your playground

Your playground is a single-node `kind` cluster that runs Kubernetes 1.35. Your own credentials in this cluster have the `cluster-admin` role. So you can create any RBAC object, and you can act as other identities. The cluster starts with this content:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The ServiceAccount `shuttle`. It has no permission to read anything |
| `outpost` | An empty namespace. The commands in this module grant and test access here |

Start your playground now and keep it running while you read:

<!-- astrona:playground -->
