---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Playground Guide

This playground is a private `kind` cluster running Kubernetes 1.35 for the module "Authentication, Anonymous Access And Authorization Modes". It is separate from the lab clusters. Nothing in it is graded, so you can change and break things freely.

## Connect

Use the private kubeconfig of this playground and check the context before you run anything:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-030-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-030-02" || exit 1
```

Your credentials have the `cluster-admin` role. Run both commands again in every new terminal.

## What is in the cluster

The namespace `starfleet` holds the Deployment `probe` with two replicas, its Service, and the pod `shuttle`. The namespace `outpost` holds the pod `drifter`. All of them use the default ServiceAccount of their namespace. Two ClusterRoleBindings exist: `anonymous-viewer` gives `view` to the group `system:unauthenticated`, and `ops-viewer` gives `view` to the group `ops`.

## Practice tasks

1. Read your own identity with `kubectl auth whoami` and decode a ServiceAccount token.
2. Define the `call_api` helper and compare anonymous, token and invalid-token requests.
3. Find the binding that lets anonymous callers list Pods and delete it.
4. Read the live `--authorization-mode` flag and test an identity with `--as`.

The module text gives the exact commands for each task. Use `kubectl get` and `kubectl describe` to inspect any object you create, and delete the objects of a task when you finish it.

## Reset

If the cluster is in a state you cannot explain, destroy the playground and launch a new one. The cluster starts from the same content every time.
