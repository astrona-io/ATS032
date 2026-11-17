---
exam_objectives:
- Restrict access to Kubernetes API
---
# Remove RBAC Grants For Anonymous Requests

Allow about 8 minutes for the tasks.

An audit shows that a caller with no credentials can read data in this cluster. The API server gives such a request the user `system:anonymous` and the group `system:unauthenticated`. Somebody bound roles to these subjects. Find the bindings and remove them, but keep the access that the cluster and the `ops` team need.

## Connect to the lab

Use a shell on your own machine. The kubeconfig file holds the address and the credentials of this lab's cluster, and `kubectl` uses it.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-030-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-030-02-01" || exit 1
control_plane="astro-ats-032-lab-030-02-01-control-plane"
```

To send a request with no credentials, run `curl` on the control plane node, for example `podman exec $control_plane curl -sk https://127.0.0.1:6443/version`. If your machine uses Docker, write `docker exec` instead.

## Tasks

1. Remove every ClusterRoleBinding that grants a role to `system:anonymous` or `system:unauthenticated`, except the built-in bindings that the API server creates itself.
2. Remove every RoleBinding in `starfleet-032-030-02-01` and `outpost-032-030-02-01` that grants a role to `system:anonymous` or `system:unauthenticated`.

After the change, an anonymous request must get `403 Forbidden` for the Pods of `outpost-032-030-02-01` and for the Secrets of `starfleet-032-030-02-01`. An anonymous request to `/version` must still return `200`.

Do not change the ClusterRoleBinding `ops-viewer`: the group `ops` must still be able to list Pods in `starfleet-032-030-02-01`. Do not change the built-in ClusterRole or ClusterRoleBinding `system:public-info-viewer`, and do not switch anonymous authentication off.
