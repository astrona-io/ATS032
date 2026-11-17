---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Drain A Worker Node With A PodDisruptionBudget

Allow about 10 minutes for the tasks.

The worker node of the `starfleet` cluster gets a new kubelet tonight. Before the upgrade, the node must be empty. The `probe` application must stay available during the move, and the `drifter` Pod in `outpost` must keep running.

## Connect to the lab

Use a shell on your own machine. The kubeconfig file holds the address and the credentials of this lab's cluster, and `kubectl` uses it.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-040-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-040-01-01" || exit 1
node_name="astro-ats-032-lab-040-01-01-control-plane"
worker_name="astro-ats-032-lab-040-01-01-worker"
```

## Tasks

The cluster has one control plane node and one worker node. The Deployment `probe` in the namespace `starfleet-032-040-01-01` runs two Pods with the label `app=probe`, both on the worker. Its Pods tolerate the control plane taint `node-role.kubernetes.io/control-plane:NoSchedule`. The PodDisruptionBudget `probe` protects them. The bare Pod `drifter` in the namespace `outpost-032-040-01-01` also runs on the worker. A bare Pod has no controller, so nothing recreates it after an eviction.

1. Change the disruption budget so that a drain can evict the `probe` Pods. Keep a PodDisruptionBudget that selects `app: probe` in `matchLabels`, and every such budget must allow at least one disruption.
2. Move `drifter` to the control plane node `astro-ats-032-lab-040-01-01-control-plane`. Keep its name, namespace, label `app=drifter`, image `docker.io/library/busybox:1.37.0` and `sleep` command, and keep it a bare Pod. It must be Running and Ready.
3. Drain the worker `astro-ats-032-lab-040-01-01-worker`. Only DaemonSet Pods may stay on it, and two `probe` Pods must be available. Leave the worker cordoned for the upgrade.

Do not delete the Deployment `probe`.
