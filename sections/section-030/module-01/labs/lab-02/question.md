---
exam_objectives:
- Restrict access to Kubernetes API
---
# Harden The Kubelet On A Worker Node

Allow about 10 minutes for the tasks.

A security scan of the cluster reports that the kubelet on the worker node answers requests from anyone. The kubelet is the node agent that starts containers and serves its own HTTPS API on port 10250. Close that API again without breaking the node.

## Connect to the lab

Use a shell on your own machine. The kubeconfig file holds the address and the credentials of this lab's cluster, and `kubectl` uses it.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-030-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-030-01-02" || exit 1
worker="astro-ats-032-lab-030-01-02-worker"
```

The node of a `kind` cluster is a container on your machine. Open a shell on the worker node with `podman exec -it "$worker" bash`. If your machine uses Docker, write `docker exec` instead. The kubelet reads its configuration from `/var/lib/kubelet/config.yaml`.

## Tasks

Change the kubelet configuration on the worker node `astro-ats-032-lab-030-01-02-worker`:

1. Turn off anonymous authentication. Keep webhook token authentication on.
2. Set the authorization mode to `Webhook`.
3. Turn off the read-only port 10255.
4. Restart the kubelet so that it uses the new configuration.

After the change, an anonymous HTTPS request to port 10250 of the worker must get `401 Unauthorized`, and port 10255 must refuse connections. The worker node must be `Ready`, and `kubectl logs` must still work for the Pod `probe` in `starfleet-032-030-01-02`, which runs on the worker.
