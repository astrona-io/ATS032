---
exam_objectives:
- Restrict access to Kubernetes API
---
# Remove Static Token Authentication From The API Server

Allow about 8 minutes for the tasks.

The API server of this cluster still accepts a static token file. Each line of that file holds a token, a user name and groups, and one token in it gives full administrator rights. A static token never expires and changes only when the API server restarts. Remove this authentication method.

## Connect to the lab

The lab is a virtual machine (VM) with one Kubernetes node. Open a shell on it from your own machine:

```sh
astrona ssh astro-ats-032-lab-030-02-02
```

You are the user `student`. You can run commands as root with `sudo`, and `kubectl` already works for this cluster. The node is called `controlplane`. The kubelet on that node runs the kube-apiserver as a static Pod from `/etc/kubernetes/manifests/kube-apiserver.yaml`. Only root can change that file.

## Tasks

1. Remove the `--token-auth-file` flag from the kube-apiserver static Pod manifest.
2. Delete the token file that the flag names.
3. Wait until the API server is running and ready again.

After the change, a request with the old static token must get `401 Unauthorized`. The `kube-apiserver` Pod in `kube-system` must be `Ready`, and `kubectl get --raw /readyz` must print `ok`. Leave the directory `/var/lib/ats-032-lab` on the node as it is, because the grader uses it.

## How the answer is checked

The grader runs three checks:

- The manifest `/etc/kubernetes/manifests/kube-apiserver.yaml` has no `--token-auth-file` flag, and the token file is gone from `/etc/kubernetes`.
- A request to the API server with the old static token gets `401`.
- The `kube-apiserver-controlplane` Pod runs without the flag, is Ready, and `/readyz` returns `ok`.
