---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Playground Guide

This playground is a private `kind` cluster running Kubernetes 1.35 for the module "Dedicated Least-Privilege ServiceAccounts". It is separate from the lab clusters. Nothing in it is graded, so you can change and break things freely.

## Connect

Use the private kubeconfig of this playground and check the context before you run anything:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-020-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-020-02" || exit 1
```

Your credentials have the `cluster-admin` role. Run both commands again in every new terminal.

## What is in the cluster

The namespace `starfleet` holds the Deployment `probe` with two replicas, its Service, the pod `shuttle`, the Role `pod-access` and the RoleBinding `default-pod-access` that gives the Role to the `default` ServiceAccount. The namespace `outpost` holds the pod `drifter`. All pods use the default ServiceAccount of their namespace.

## Practice tasks

1. Create a ServiceAccount for a workload and move a Deployment to it.
2. Create a Role with one narrow rule and bind it to a new ServiceAccount.
3. Check what each account may do with `kubectl auth can-i`.
4. Find the binding that names the `default` ServiceAccount and remove it.


The module text gives the exact commands for each task. Use `kubectl get` and `kubectl describe` to inspect any object you create, and delete the objects of a task when you finish it.

## Reset

If the cluster is in a state you cannot explain, destroy the playground and launch a new one. The cluster starts from the same content every time.
