---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Patch Nodes And Verify The Upgraded Cluster

A Kubernetes upgrade changes the cluster components. Many vulnerabilities live below them: in the operating system, the kernel and the container runtime of each node. Those layers need their own patch routine, and every routine ends with proof that the cluster is healthy again. This module covers node-level patching, a layered check that runs after any maintenance or upgrade, and the limits of going back when a change goes wrong.

The key idea is simple: **a maintenance window is not finished when the last command succeeds. It is finished when a check proves that nodes, control plane, workloads and budgets are back to normal.** The window can leave a cordoned node, a taint, a Pod that cannot be scheduled or a budget that blocks the next drain, and none of these shows up as an error.

The module has three parts. **Patch The Operating System And Container Runtime On Nodes** shows the rotation of drain, patch, reboot and return, and what a window can leave behind. **Verify The Cluster After An Upgrade** gives a layered check from the nodes to a real request. **Rollback Limits And Restore Drills** explains why a minor upgrade cannot be undone with a downgrade, when to restore etcd, and how to test a restore before you need it.

## Learning objectives

After this module you can:

- Describe the rotation for patching the operating system, kernel and container runtime of a node without losing the application.
- Find and remove the leftovers of a maintenance window: cordon, taints and Pods that cannot be scheduled.
- Run a layered post-upgrade check of nodes, API health, system Pods, disruption budgets, deprecated API use and a real request.
- Explain why Kubernetes has no downgrade path and when to fix forward or restore etcd.
- Plan etcd snapshots and restore drills so a restore works on the first real try.

## Before you start

You need Kubernetes basics: Pods, Deployments, nodes, `kubectl cordon` and `kubectl drain`. The playground is a `kind` cluster, whose nodes are containers. Host commands that need `apt` or `systemctl` are shown to read and are not run in it. Every `kubectl` command runs in the playground.

Your terminal must use the playground's private kubeconfig, the file that holds the cluster address and credentials for `kubectl`. Run these two commands once in every new terminal:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-040-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-040-03" || exit 1
```

The playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and two workers. Your own credentials have the `cluster-admin` role. The cluster starts with this content:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The Deployment `probe` with two replicas and a Service `probe`, and the Pod `shuttle`, a client with BusyBox tools. `shuttle` runs on the second worker |
| `outpost` | The Pod `drifter`, a client with BusyBox tools. It runs on the second worker |

The nodes are named `astro-ats-032-playground-040-03-control-plane`, `astro-ats-032-playground-040-03-worker` and `astro-ats-032-playground-040-03-worker2`.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
