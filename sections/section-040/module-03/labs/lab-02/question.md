---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Restart The Container Runtime On A Drained Worker

Allow about 10 minutes for the tasks.

A patched `containerd` package is already installed on the worker of the `starfleet` cluster. The new binary only runs after the service restarts. The worker is cordoned for the maintenance window, and both `probe` Pods still run on it.

## Connect to the lab

Use a shell on your own machine. The kubeconfig file holds the address and the credentials of this lab's cluster, and `kubectl` uses it.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-040-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-040-03-02" || exit 1
worker_name="astro-ats-032-lab-040-03-02-worker"
```

The node of a `kind` cluster is a container on your machine. Run a command inside it with `podman exec "$worker_name" <command>`. If your machine uses Docker, write `docker exec` instead. The node runs `systemd`, so `systemctl` works inside it.

## Tasks

The Deployment `probe` in the namespace `starfleet-032-040-03-02` has two replicas and a PodDisruptionBudget (a Kubernetes object that limits how many Pods of an application may be evicted at the same time).

1. Drain the worker `astro-ats-032-lab-040-03-02-worker`, so that both `probe` Pods that run on it now are evicted and two new `probe` Pods are available on another node.
2. Restart the `containerd` service on the worker. It must be `active` afterwards.
3. Make the worker Ready and schedulable again.

Do not delete the Deployment or the PodDisruptionBudget, and do not restart the worker container itself.
