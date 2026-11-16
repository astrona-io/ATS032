---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Remove Anonymous Access To The API

Solve this question on: `terminal`

The `ops` team in `outpost-032-030-02-01` has asked why a stranger could list Pods without logging in.

## Objective

Close the binding that lets unauthenticated callers read cluster data while keeping health and version access and the binding of a named team.

## Starting state

The `outpost-032-030-02-01` operations team noticed that the API server answers a request without a credential. The ClusterRoleBinding `anonymous-viewer` gives the `view` ClusterRole to the group `system:unauthenticated`. The binding `ops-viewer` gives `view` to the group `ops` and is correct. The Deployment `probe` in `starfleet-032-030-02-01` can send requests to the API server. Do not change the Deployment.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-030-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-030-02-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

Allow 3–5 minutes for task work. Cluster startup adds time.

## Tasks

1. Find the binding that gives cluster data to unauthenticated callers, and remove the ClusterRoleBinding `anonymous-viewer`.
2. Prove the result from a `probe` Pod: an anonymous request to `/api/v1/namespaces/starfleet-032-030-02-01/pods` returns `403`, and an anonymous request to `/version` still returns `200`.

## Constraints

- Keep the ClusterRoleBinding `ops-viewer` unchanged; the group `ops` must still list Pods in `starfleet-032-030-02-01`.
- Do not edit any built-in role, and do not change the Deployment `probe`.

## How the answer is checked

The grader runs one check. It checks that `anonymous-viewer` is gone and that an anonymous Pod list from a `probe` Pod gets `403`. It also checks that `/version` still answers `200`, that `ops-viewer` is unchanged and that the group `ops` can list Pods.
