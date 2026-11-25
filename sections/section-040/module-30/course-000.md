---
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

You need Kubernetes basics: Pods, Deployments, nodes, `kubectl cordon` and `kubectl drain`. You also need a little Linux: `sudo`, `apt` and `systemctl`.

The playground is a virtual machine (VM) with Ubuntu 24.04 and a one-node Kubernetes 1.35 cluster that `kubeadm` installed. The node is called `controlplane`. It runs the control plane and the example workloads, and it uses `containerd` as its container runtime. Because the VM is a real host, every command in this module runs in it, including `apt`, `systemctl`, `etcdctl` and `etcdutl`.

Open a shell on the VM from your own machine:

```sh
astrona ssh astro-ats-032-playground-040-03
```

You are the user `student`. `kubectl` already works and has the `cluster-admin` role, and you can run host commands as root with `sudo`. The cluster starts with this content:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The Deployment `probe` with two replicas and a Service `probe`, and the Pod `shuttle`, a client with BusyBox tools |
| `outpost` | The Pod `drifter`, a client with BusyBox tools |

`shuttle` and `drifter` are bare Pods: no controller such as a Deployment manages them. The tools `etcdctl` and `etcdutl` are installed on the node.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
