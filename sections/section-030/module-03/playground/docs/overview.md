---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Playground Guide

This playground is a private `kind` cluster running Kubernetes 1.35 for the module "Admission Control For API Writes". It is separate from the lab clusters. Nothing in it is graded, so you can change and break things freely.

## Connect

Use the private kubeconfig of this playground and check the context before you run anything:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-030-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-030-03" || exit 1
```

Your credentials have the `cluster-admin` role. Run both commands again in every new terminal.

## What is in the cluster

The namespace `starfleet` holds the Deployment `probe` with two replicas, its Service, and the pod `shuttle`. The namespace `outpost` holds the pod `drifter`. No Pod Security label and no admission policy exists yet.

## Practice tasks

1. Create a privileged Pod in `outpost`, label the namespace with the enforce level `baseline` and create the Pod again.
2. Add a warn label for `restricted` and apply a plain Pod.
3. Create a ValidatingAdmissionPolicy and a binding that reject NodePort Services in `outpost`.
4. Create a webhook configuration that points at a missing Service and compare `Fail` with `Ignore`.

The module text gives the exact commands for each task. Use `kubectl get` and `kubectl describe` to inspect any object you create, and delete the objects of a task when you finish it.

## Reset

If the cluster is in a state you cannot explain, destroy the playground and launch a new one. The cluster starts from the same content every time.
