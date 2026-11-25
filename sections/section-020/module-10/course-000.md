# Restrict ServiceAccount Credentials

A pod that calls the Kubernetes API needs an identity. Kubernetes gives pods that identity through a ServiceAccount. A ServiceAccount is an API object that names a workload identity inside one namespace.

By default, every pod receives a credential for the ServiceAccount named `default`. This happens even when the application never talks to the API. If an attacker runs code in that container, the credential is already there to steal.

This module shows how the credential reaches the pod, how to stop Kubernetes from mounting it, and how to keep the identity itself small. Keep one rule in mind: **a credential that is not mounted cannot be stolen from the container, and a ServiceAccount that has no grants cannot do harm with a stolen token.**

## What you will learn

After this module, you can:

- explain how a pod gets its ServiceAccount and what the kubelet mounts in the container;
- disable token mounting in a ServiceAccount and in a pod, and say which setting takes precedence;
- check that a pod has no token, and list the permissions of the `default` ServiceAccount;
- request a short-lived token with `kubectl create token`, and set an audience and a lifetime on a projected token;
- explain why a Secret of type `kubernetes.io/service-account-token` is a risk.

## How the module is laid out

You start with **ServiceAccounts And The Default Token**. It shows the identity of a pod, the projected token volume and the permissions of the `default` account. **Disable Automounting And Minimize Permissions** then sets `automountServiceAccountToken` on the ServiceAccount and on the pod, and explains which setting wins.

**Bound Tokens, Audience And Legacy Secrets** closes the module. It covers the TokenRequest API, projected tokens with an audience and a lifetime, and the long-lived token Secret that you should avoid. A lab follows the automounting part and another follows the bound token part, so you can practise each skill right away.

## Before you start

You should know the Kubernetes basics: pods, namespaces, Deployments, YAML manifests and `kubectl exec`. You do not need to know Role-Based Access Control (RBAC) in depth. It is enough to know that a Role grants permissions to a subject, such as a user or a ServiceAccount.

## Your playground

The commands run against a playground cluster. Your terminal must use the private kubeconfig of the playground. A kubeconfig is the file that holds the cluster address and the credentials for `kubectl`. Run these two commands once in every new terminal:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-020-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-020-01" || exit 1
```

The first command points `kubectl` at the playground. The second command stops if the current context is not the playground cluster, so you never change another cluster by mistake.

The playground is a `kind` cluster that runs Kubernetes 1.35, with one control-plane node and one worker node. Your own credentials have the `cluster-admin` role. The cluster already runs these workloads, and all of them use the `default` ServiceAccount of their namespace:

| Namespace | Object | What it is |
| --- | --- | --- |
| `starfleet` | `probe` Deployment, two pods, labels `app: probe` and `release: probe` | A small Python web server that listens on port 8080 |
| `starfleet` | `probe` Service | Port 80, forwards to port 8080 of the `probe` pods |
| `starfleet` | `probe-code` ConfigMap | The code of the `probe` web server |
| `starfleet` | `shuttle` pod, label `app: shuttle` | A client pod with BusyBox tools |
| `outpost` | `drifter` pod, label `app: drifter` | A client pod with BusyBox tools, in another namespace |

Start your playground now and keep it running while you read:

<!-- astrona:playground -->
