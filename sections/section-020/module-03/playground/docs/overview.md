---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Playground Guide

This playground is a private `kind` cluster running Kubernetes 1.35 for the module "Audit ServiceAccount Use And Tokens". It is separate from the lab clusters. Nothing in it is graded, so you can change and break things freely.

## Connect

Use the private kubeconfig of this playground and check the context before you run anything:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-020-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-020-03" || exit 1
```

Your credentials have the `cluster-admin` role. Run both commands again in every new terminal.

## What is in the cluster

The namespace `starfleet` holds the Deployment `probe` with two replicas, its Service and the pod `shuttle`. The namespace `outpost` holds the pods `drifter`, `ledger-client` and `archive-reader`, the ServiceAccounts `ledger` and `archive`, the Secret `ledger-legacy-token`, the ClusterRoleBinding `ledger-edit` and the RoleBinding `outpost-all-view`.

## Practice tasks

1. List every pod with its ServiceAccount and automount setting.
2. List the long-lived token Secrets of the cluster and the ServiceAccount of each.
3. Find the bindings that reach a ServiceAccount, directly or through a group.
4. Request a token with a different audience and test it against the API server.


The module text gives the exact commands for each task. Use `kubectl get` and `kubectl describe` to inspect any object you create, and delete the objects of a task when you finish it.

## Reset

If the cluster is in a state you cannot explain, destroy the playground and launch a new one. The cluster starts from the same content every time.
