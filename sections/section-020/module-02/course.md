---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Dedicated Least-Privilege ServiceAccounts

A ServiceAccount is the identity of a workload inside one namespace, and Kubernetes grants permissions to that identity through RBAC (role-based access control). If many workloads share one identity, they also share every permission that identity ever receives. A grant added for one application then reaches all the others. This module shows how to give each workload its own ServiceAccount, how to keep a new ServiceAccount free of permissions until a workload needs one, and how to clean up the `default` ServiceAccount that every namespace has.

Keep one sentence in mind for this module: **one workload, one ServiceAccount, and only the permissions that workload uses.** You will move a Deployment to its own account, create an account with a single narrow rule, test the result with permission checks, and remove a grant that someone attached to `default`.

The module has three parts. **One ServiceAccount For Each Workload** creates an account, assigns it to a Deployment and explains why a pod cannot change its account later. **Grant Only What The Workload Uses** writes a Role with narrow rules, binds it to one account and tests it with `kubectl auth can-i`. **Clean Up The Default ServiceAccount** finds bindings that name `default`, removes them and turns off token mounting for the account in every namespace you own.

## Learning objectives

After this module you can:

- Create a ServiceAccount for one workload and assign it to a Deployment or a pod.
- Explain why the ServiceAccount of a pod cannot be changed after the pod is created.
- Write a Role with a minimal rule list and bind it to one ServiceAccount with a RoleBinding.
- Test what a ServiceAccount may do with `kubectl auth can-i` and `--as`.
- Find and remove grants on the `default` ServiceAccount and turn off its token mounting.

## Before you start

You need Kubernetes basics: pods, namespaces, Deployments, YAML manifests and `kubectl exec`. You should know that a pod receives a ServiceAccount token and that `automountServiceAccountToken: false` stops the token from being mounted.

The commands run against a playground cluster. Your terminal must use the playground's private kubeconfig, the file that holds the cluster address and credentials for `kubectl`. Run these two commands once in every new terminal:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-020-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-020-02" || exit 1
```

The playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and one worker node. Your own credentials have the `cluster-admin` role. The cluster starts with this content:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The Deployment `probe` with two replicas, a Service `probe` and the pod `shuttle`. All of them use the `default` ServiceAccount. The Role `pod-access` and the RoleBinding `default-pod-access` give that Role to the `default` ServiceAccount |
| `outpost` | The pod `drifter`, which uses the `default` ServiceAccount |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
