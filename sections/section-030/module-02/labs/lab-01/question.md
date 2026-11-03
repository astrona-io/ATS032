---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Remove Anonymous Access To The API

The `ops` team in `outpost` has asked why a stranger could list Pods without logging in.

## Objective

Close the binding that lets unauthenticated callers read cluster data while keeping health and version access and the binding of a named team.

## Starting state

The `outpost` operations team noticed that the API server answers a request without a credential. The ClusterRoleBinding `anonymous-viewer` gives the `view` ClusterRole to the group `system:unauthenticated`. The binding `ops-viewer` gives `view` to the group `ops` and is correct. The Deployment `probe` in `starfleet` can send requests to the API server. Do not change the Deployment.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-030-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-030-02-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Required result

Remove the ClusterRoleBinding `anonymous-viewer`. After the change, an anonymous request from a `probe` Pod to `/api/v1/namespaces/starfleet/pods` must return `403`, and an anonymous request to `/version` must still return `200`. The ClusterRoleBinding `ops-viewer` must stay unchanged, and the group `ops` must still be able to list Pods in `starfleet`. Do not edit any built-in role.

## Verify The Result

The grader checks the stated resource fields and live evidence. Wait for controller convergence before submitting. Inspect actual results rather than relying on a sample transcript.
