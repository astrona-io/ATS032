---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Minimize Exposure With Role Based Access Control

The Kubernetes API server denies every request that no rule allows. Role Based Access Control (RBAC) is the authorization mode that holds those rules. Each rule says which identity may perform which action on which resource, and in which namespace. A cluster is only as exposed as the sum of these rules, so reading and trimming them is one of the main hardening tasks for the Certified Kubernetes Security Specialist (CKS) exam.

Keep one sentence in mind for this module: **RBAC only adds permissions, so the effective access of an identity is the union of every Role and ClusterRole bound to it, and the only way to reduce exposure is to bind less.** You will build a narrow grant for the `shuttle` ServiceAccount, reuse a ClusterRole through a RoleBinding, hit the escalation check that stops an identity from granting more than it holds, and remove a grant while another one still allows the same action.

The module has three parts. **Roles, Bindings And Scope** explains the four RBAC objects, the fields of a rule, and how a namespaced grant is built and tested. **ClusterRoles, Reuse And Escalation Prevention** binds the built-in `view` ClusterRole inside one namespace and shows why an identity cannot create a Role that is larger than its own permissions. **Additive Grants, Dangerous Verbs And Auditing Access** shows that removing one binding does not remove access that a second binding gives, lists the permissions that are riskier than they look, and shows how to review who can do what.

## Learning objectives

After this module you can:

- Name the four RBAC objects and say which one limits a grant to a namespace.
- Write a Role and a RoleBinding that give a ServiceAccount only the verbs, resources and namespace it needs.
- Test an identity with `kubectl auth can-i` and `kubectl auth can-i --list`, using `--as` to act as a ServiceAccount.
- Explain why RBAC has no deny rule and what that means when you remove a grant.
- Name the verbs and resources that give indirect or broad authority, such as `list` on Secrets, `create` on Pods, `escalate`, `bind` and `impersonate`.

## Before you start

You need Kubernetes basics: pods, namespaces, YAML manifests, and the commands `kubectl get` and `kubectl apply`. You do not need any earlier module.

The commands run against a playground cluster. Your terminal must use the playground's private kubeconfig, the file that holds the cluster address and credentials for `kubectl`. Run these two commands once in every new terminal:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-010-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-010-01" || exit 1
```

The playground is a single-node `kind` cluster running Kubernetes 1.35. Your own credentials in this cluster have the `cluster-admin` role, so you can create any RBAC object and act as other identities. The cluster starts with this content:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The ServiceAccount `shuttle`. It has no permission to read anything |
| `outpost` | An empty namespace. The commands in this module grant and test access here |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
