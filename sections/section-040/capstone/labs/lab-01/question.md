---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Run A Node Patch Window End To End

The first worker must be patched tonight. The window has started: the node is cordoned and tainted. The drain has not run yet, and it will not succeed as the cluster stands. You finish the maintenance, record what the cluster runs, and leave the cluster healthy.

## Objective

Prepare the application for a drain, drain the first worker without forcing anything, mark the node as patched, return it to service and record the versions.

## Starting state

The first worker is cordoned and has the taint `maintenance=patching:NoSchedule`. The Deployment `probe` in `starfleet` runs two replicas, one on each worker, and the Deployment does not allow two replicas on one node. A PodDisruptionBudget named `probe` with `minAvailable: 2` exists. The bare Pod `drifter` in `outpost` runs on the first worker. The bare Pod `shuttle` in `starfleet` runs on the second worker. The ConfigMap `maintenance-baseline` in `starfleet` records the identity of the `probe` Pod that runs on the first worker now.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-040-capstone-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-040-capstone-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Required result

1. Replace the PodDisruptionBudget `probe` so that it uses `maxUnavailable: 1` and no `minAvailable`.
2. Move the Pod `drifter` to the second worker. It keeps its name, namespace, label `app: drifter` and image, and it runs `sleep 3600`. Do not use `--force` on the drain.
3. Drain the first worker with `--ignore-daemonsets` and a bounded timeout. The `probe` Pod on that node must be replaced by a new Pod.
4. Label the first worker `patch-status=done`.
5. Create the ConfigMap `version-inventory` in `starfleet` with the keys `server-version` (the API server `gitVersion`), `kubelet-worker` (the kubelet version of the first worker), `container-runtime-worker` (the container runtime version of the first worker) and `probe-image` (the image of the Deployment `probe`), all read from the live cluster.
6. Return the first worker to service: uncordon it and remove the taint with the key `maintenance`.

When you finish, both `probe` replicas must be running and ready on two different nodes, all three nodes must be Ready, and the `shuttle` Pod must still reach `http://probe/`. Do not change the Deployment `probe`. This exercise does not perform a Kubernetes binary upgrade.

## Verify The Result

The grader checks the node, the budget, the Pods, the identity of the replaced `probe` Pod, the ConfigMap and one request from `shuttle`. Wait for the Deployment to finish after the node returns, and repeat your own checks before you submit.
