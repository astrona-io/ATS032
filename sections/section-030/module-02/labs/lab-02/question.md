---
exam_objectives:
- Restrict access to Kubernetes API
---
# Remove Static Token Authentication From The API Server

Allow about 8 minutes for the tasks.

The API server of this cluster still accepts a static token file. Each line of that file holds a token, a user name and groups, and one token in it gives full administrator rights. A static token never expires and changes only when the API server restarts. Remove this authentication method.

## Connect to the lab

Use a shell on your own machine. The kubeconfig file holds the address and the credentials of this lab's cluster, and `kubectl` uses it.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-030-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-030-02-02" || exit 1
control_plane="astro-ats-032-lab-030-02-02-control-plane"
```

The node of a `kind` cluster is a container on your machine. Open a shell on the control plane node with `podman exec -it "$control_plane" bash`. If your machine uses Docker, write `docker exec` instead. The kube-apiserver runs as a static Pod from `/etc/kubernetes/manifests/kube-apiserver.yaml`.

## Tasks

1. Remove the `--token-auth-file` flag from the kube-apiserver static Pod manifest.
2. Delete the token file that the flag names.
3. Wait until the API server is running and ready again.

After the change, a request with the old static token must get `401 Unauthorized`. The `kube-apiserver` Pod in `kube-system` must be `Ready`, and `kubectl get --raw /readyz` must print `ok`. Leave the directory `/var/lib/ats-032-lab` on the node as it is; the grader uses it.
