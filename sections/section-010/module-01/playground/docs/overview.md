---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Playground Guide

This playground is a private `kind` cluster running Kubernetes 1.35 for the module "Minimize Exposure With Role Based Access Control". It is separate from the lab clusters. Nothing in it is graded, so you can change and break things freely.

## Connect

Use the private kubeconfig of this playground and check the context before you run anything:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-010-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-010-01" || exit 1
```

Your credentials have the `cluster-admin` role. Run both commands again in every new terminal.

## What is in the cluster

The cluster has two namespaces. `starfleet` holds the ServiceAccount `shuttle`, which has no permission to read anything. `outpost` is empty, and the module grants and tests access there.

## Practice tasks

1. Check what `shuttle` may do before any grant exists.
2. Create a Role and a RoleBinding in `outpost` and test the allowed and the denied actions.
3. Bind the `view` ClusterRole in one namespace and compare the result.
4. Remove one binding and check whether the access is really gone.

The module text gives the exact commands for each task. Use `kubectl get` and `kubectl describe` to inspect any object you create, and delete the objects of a task when you finish it.

## Reset

If the cluster is in a state you cannot explain, destroy the playground and launch a new one. The cluster starts from the same content every time.
