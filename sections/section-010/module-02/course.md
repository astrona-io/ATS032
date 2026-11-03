---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Audit And Narrow Effective Access

A cluster that has run for a year holds many Roles, ClusterRoles and bindings that nobody remembers writing. Some of them give a workload far more than it uses. Role Based Access Control (RBAC) is the authorization mode of the Kubernetes API server, and it has no deny rule, so the only way to reduce exposure is to find every grant that reaches an identity and replace the broad ones with narrow ones. This is the work of an access review, and it is a core task of the Certified Kubernetes Security Specialist (CKS) exam.

Keep one sentence in mind for this module: **the effective access of an identity is the union of every rule in every binding that names it or one of its groups, so an audit starts from the identity, collects every binding, and ends with a test of what the API server really allows.** You will ask the authorizer precise questions, find all bindings that reach the `scout` ServiceAccount and the `starfleet-crew` group, and replace a broad built-in role with a rule that covers only what the workload needs.

The module has three parts. **Ask The Authorizer Precisely** shows what `kubectl auth can-i` asks the API server, how to test a resource name, a subresource, a non-resource URL, a group and a whole namespace, and what the test cannot tell you. **Find Every Grant That Reaches An Identity** lists the bindings of a cluster in a form that can be searched, and follows an identity through its names and its groups to the rules it receives. **Rewrite A Broad Grant As Least Privilege** replaces a built-in role with a narrow Role, in the safe order: add, test, remove, test again.

## Learning objectives

After this module you can:

- Test an identity for a verb, a resource, a resource name, a subresource, a non-resource URL and a whole namespace with `kubectl auth can-i`.
- Act as a user in a group with `--as` and `--as-group`, and explain which request checks the answer.
- List every RoleBinding and ClusterRoleBinding with its role and subjects, and search them for an identity and for broad groups.
- Explain which names an identity has (its own name, its groups and its automatic ServiceAccount groups).
- Replace a broad grant with a narrow Role and RoleBinding in the order that never leaves the workload without access.
- Explain why `resourceNames` cannot limit a `create` request.

## Before you start

You need Kubernetes basics: pods, namespaces, YAML manifests, and the commands `kubectl get` and `kubectl apply`. You should know that a Role holds rules and a binding gives a role to subjects. You do not need any earlier module.

The commands run against a playground cluster. Your terminal must use the playground's private kubeconfig, the file that holds the cluster address and credentials for `kubectl`. Run these two commands once in every new terminal:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-010-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-010-02" || exit 1
```

The playground is a single-node `kind` cluster running Kubernetes 1.35. Your own credentials in this cluster have the `cluster-admin` role, so you can create any RBAC object and act as other identities. The cluster starts with this content:

| Where | What is in it |
| --- | --- |
| Namespace `starfleet` | The ServiceAccounts `shuttle` and `scout` |
| Namespace `outpost` | The ConfigMap `scout-report`, the Role `configmap-reader` with its RoleBinding `shuttle-configmap-reader`, and the RoleBinding `crew-view` that gives the built-in `view` ClusterRole to the group `starfleet-crew` |
| Cluster scope | The ClusterRoleBinding `scout-edit-everywhere`, which gives the built-in `edit` ClusterRole to `scout` in every namespace |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
