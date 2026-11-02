---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Playground Guide

This playground is a private `kind` cluster running Kubernetes 1.35 for the module "Restrict ServiceAccount Credentials". It is separate from the lab clusters. Nothing in it is graded, so you can change and break things freely.

## Connect

Use the private kubeconfig of this playground and check the context before you run anything:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-020-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-020-01" || exit 1
```

Your credentials have the `cluster-admin` role. Run both commands again in every new terminal.

## What is in the cluster

The namespace `starfleet` holds the Deployment `probe` with two replicas, its Service, and the pod `shuttle`. The namespace `outpost` holds the pod `drifter`. All of them use the default ServiceAccount of their namespace.

## Practice tasks

1. Look at the volumes and files of a pod that uses the `default` ServiceAccount.
2. List the permissions of the `default` ServiceAccount.
3. Create a ServiceAccount with automounting off and compare pods that use it.
4. Request a short-lived token and list the token Secrets of the cluster.

The module text gives the exact commands for each task. Use `kubectl get` and `kubectl describe` to inspect any object you create, and delete the objects of a task when you finish it.

## Reset

If the cluster is in a state you cannot explain, destroy the playground and launch a new one. The cluster starts from the same content every time.
