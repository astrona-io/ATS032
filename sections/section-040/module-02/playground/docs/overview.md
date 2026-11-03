---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Playground Guide

This playground is a private `kind` cluster running Kubernetes 1.35 for the module "Track Vulnerabilities And Inventory Versions". It is separate from the lab clusters. Nothing in it is graded, so you can change and break things freely.

## Connect

Use the private kubeconfig of this playground and check the context before you run anything:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-040-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-040-02" || exit 1
```

Your credentials have the `cluster-admin` role. Run both commands again in every new terminal.

## What is in the cluster

The cluster has one control-plane node and two workers, named with the suffixes `-control-plane`, `-worker` and `-worker2`. The namespace `starfleet` holds the Deployment `probe` with two replicas, its Service, and the pod `shuttle`. The namespace `outpost` holds the pod `drifter`. Both pods run on the second worker.

## Practice tasks

1. Read the API server version from the `/version` endpoint and compare it with the client version.
2. List the kubelet version, container runtime, operating system and kernel of every node.
3. List the images of every Pod, and read the image digest that each running container uses.
4. Store the versions in a ConfigMap and label the nodes with a patch wave.

The module text gives the exact commands for each task. Use `kubectl get` and `kubectl describe` to inspect any object you create, and delete the objects of a task when you finish it.

## Reset

If the cluster is in a state you cannot explain, destroy the playground and launch a new one. The cluster starts from the same content every time.
