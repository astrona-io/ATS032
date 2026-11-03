---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Playground Guide

This playground is a private `kind` cluster running Kubernetes 1.35 for the module "Subjects, Built-In Roles And Wildcards". It is separate from the lab clusters. Nothing in it is graded, so you can change and break things freely.

## Connect

Use the private kubeconfig of this playground and check the context before you run anything:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-010-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-010-03" || exit 1
```

Your credentials have the `cluster-admin` role. Run both commands again in every new terminal.

## What is in the cluster

The `starfleet` namespace holds the ServiceAccount `probe`. The `outpost` namespace holds the Role `crew-operator`, whose rule uses `*` for API groups, resources and verbs, and the RoleBinding `outpost-crew-operator` that gives it to the group `outpost-crew`.

## Practice tasks

1. Bind the `view` ClusterRole to a user, a group and a ServiceAccount in one RoleBinding and test each one with `--as` and `--as-group`.
2. List the default bindings of `cluster-admin`, `system:basic-user` and `system:discovery`.
3. Build an aggregated ClusterRole from two labelled ClusterRoles and add the second one after the binding exists.
4. Find the wildcard in `crew-operator` and replace it with explicit rules.

The module text gives the exact commands for each task. Use `kubectl get` and `kubectl describe` to inspect any object you create, and delete the objects of a task when you finish it.

## Reset

If the cluster is in a state you cannot explain, destroy the playground and launch a new one. The cluster starts from the same content every time.
