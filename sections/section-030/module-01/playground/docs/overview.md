---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Playground Guide

This playground is a private `kind` cluster running Kubernetes 1.35 for the module "Restrict Access To The Kubernetes API". It is separate from the lab clusters. Nothing in it is graded, so you can change and break things freely.

## Connect

Use the private kubeconfig of this playground and check the context before you run anything:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-030-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-030-01" || exit 1
```

Your credentials have the `cluster-admin` role. Run both commands again in every new terminal.

## What is in the cluster

The namespace `starfleet` holds the Deployment `probe` with two replicas, its Service, and the pod `shuttle`. The namespace `outpost` holds the pod `drifter`. All of them use the default ServiceAccount of their namespace.

## Practice tasks

1. Define the `call_api` helper and compare anonymous and token requests.
2. Create a ServiceAccount, Role and RoleBinding and run the `probe` Deployment as that account.
3. Send an allowed and a denied request from the pod.
4. Print the live kube-apiserver flags and compare them with the hardening list.

The module text gives the exact commands for each task. Use `kubectl get` and `kubectl describe` to inspect any object you create, and delete the objects of a task when you finish it.

## Reset

If the cluster is in a state you cannot explain, destroy the playground and launch a new one. The cluster starts from the same content every time.
