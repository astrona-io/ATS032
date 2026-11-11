---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Restrict ServiceAccount Credentials

A pod that calls the Kubernetes API needs an identity. Kubernetes gives that identity to pods through a ServiceAccount: an API object that names a workload identity inside one namespace. By default, every pod receives a credential for the ServiceAccount named `default`, even when the application never talks to the API. If an attacker runs code in that container, the credential is already there to steal. This module shows how the credential reaches the pod, how to stop it from being mounted, and how to keep the identity itself small.

Keep one sentence in mind for this module: **a credential that is not mounted cannot be stolen from the container, and a ServiceAccount that has no grants cannot do harm with a stolen token.** You will inspect what a default pod receives, turn off mounting at both levels where it can be turned off, and then use short-lived tokens with a limited audience in place of the old long-lived Secret tokens.

The module has three parts. **ServiceAccounts And The Default Token** shows the identity, the projected token volume and the permissions of the `default` account. **Disable Automounting And Minimize Permissions** sets `automountServiceAccountToken` on the ServiceAccount and on the pod, and explains which setting wins. **Bound Tokens, Audience And Legacy Secrets** covers the TokenRequest API, projected tokens with an audience and a lifetime, and the long-lived token Secret that you should avoid.

## Learning objectives

After this module you can:

- Explain how a pod gets its ServiceAccount and what the kubelet mounts in the container.
- Disable token mounting in a ServiceAccount and in a pod, and say which setting takes precedence.
- Check that a pod has no token, and list the permissions of the `default` ServiceAccount.
- Request a short-lived token with `kubectl create token` and set an audience and a lifetime on a projected token.
- Say why a Secret of type `kubernetes.io/service-account-token` is a risk.

## Before you start

You need Kubernetes basics: pods, namespaces, Deployments, YAML manifests and `kubectl exec`. You do not need RBAC knowledge beyond the idea that a Role grants permissions to a subject.

The commands run against a playground cluster. Your terminal must use the playground's private kubeconfig, the file that holds the cluster address and credentials for `kubectl`. Run these two commands once in every new terminal:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-020-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-020-01" || exit 1
```

The playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and one worker node. Your own credentials have the `cluster-admin` role. The cluster starts with this content:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The Deployment `probe` with two replicas and a Service `probe`, and the pod `shuttle`, a client with BusyBox tools. All of them use the `default` ServiceAccount |
| `outpost` | The pod `drifter`, a client with BusyBox tools. It uses the `default` ServiceAccount |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

## Independent live assessment

Prepare with [Verify The Receiver Of A Projected Token](course-03a-verify-token-audiences.md). [Restrict A Projected Token Audience](labs/lab-02/question.md) uses its own kind environment. The Pod uses an explicit short-lived token for telemetry.training; Live TokenReview accepts the intended audience and the Kubernetes API rejects the token.
