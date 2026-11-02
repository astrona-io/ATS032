---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Restrict Access To The Kubernetes API

The Kubernetes API server is the front door of the cluster. Every change to a Pod, Secret or Role, and every read of cluster state, goes through it. Whoever can send a request that the API server accepts holds a large part of the cluster. This module shows the three checks every request passes, how a workload calls the API with a narrow identity, and which settings on the API server and the kubelet close the common ways in.

Keep one sentence in mind for this module: **every request is authenticated, authorized and admitted in that order, and hardening means that each step says no to anything that is not needed.** You will send requests with and without credentials and compare the answers, give a workload a small identity and prove it, and then read the live API server configuration to see which hardening settings are in place.

The module has three parts. **How An API Request Is Checked** follows a request through authentication, authorization and admission and tests anonymous access. **A Narrow Workload Identity** builds a ServiceAccount with one Role and uses its token from inside a Pod. **Hardening The Endpoint And The Kubelet** covers API server flags, kubelet settings, network exposure, the NodeRestriction admission plugin and audit logging.

## Learning objectives

After this module you can:

- Name the three checks a request passes and the HTTP status that each failed check produces.
- Test anonymous and authenticated access to the API from inside a Pod.
- Give a workload a dedicated ServiceAccount with a Role that allows one resource, and verify the allowed and the denied requests.
- Name the API server flags and kubelet settings that control anonymous access, authorization and exposure.
- Explain what the NodeRestriction plugin limits and what an audit policy records.

## Before you start

You need Kubernetes basics: Pods, Deployments, namespaces, Services and `kubectl exec`. Basic RBAC helps: a Role lists permissions and a RoleBinding gives them to a subject.

The commands run against a playground cluster. Your terminal must use the playground's private kubeconfig, the file that holds the cluster address and credentials for `kubectl`. Run these two commands once in every new terminal:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-030-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-030-01" || exit 1
```

The playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and one worker node. Your own credentials have the `cluster-admin` role. The cluster starts with this content:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The Deployment `probe` with two replicas and a Service `probe`, which run Python and are used to send API requests. The pod `shuttle`, a client with BusyBox tools. All of them use the `default` ServiceAccount |
| `outpost` | The pod `drifter`, a client with BusyBox tools |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
