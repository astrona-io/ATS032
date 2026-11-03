---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Starting Environment

The `outpost` operations team noticed that the API server answers a request without a credential. The ClusterRoleBinding `anonymous-viewer` gives the `view` ClusterRole to the group `system:unauthenticated`. The binding `ops-viewer` gives `view` to the group `ops` and is correct. The Deployment `probe` in `starfleet` can send requests to the API server. Do not change the Deployment.

Remove the ClusterRoleBinding `anonymous-viewer`. After the change, an anonymous request from a `probe` Pod to `/api/v1/namespaces/starfleet/pods` must return `403`, and an anonymous request to `/version` must still return `200`. The ClusterRoleBinding `ops-viewer` must stay unchanged, and the group `ops` must still be able to list Pods in `starfleet`. Do not edit any built-in role.
