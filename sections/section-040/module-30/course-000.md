# Patch Nodes And Verify The Upgraded Cluster

A Kubernetes upgrade changes the cluster components, such as the API server and the `kubelet`. But many vulnerabilities live below them. They sit in the operating system, the kernel and the container runtime of each node. Those layers need their own patch routine.

Every patch routine ends with proof that the cluster is healthy again. **A maintenance window is not finished when the last command succeeds. It is finished when a check proves that nodes, control plane, workloads and budgets are back to normal.** A window can leave behind a cordoned node, a taint, a Pod that cannot be scheduled or a budget that blocks the next drain. None of these shows up as an error.

Sometimes a change goes wrong anyway. Then you need to know how far you can go back. Kubernetes has no downgrade, so the way back is a restore of etcd, the database of the cluster, and that restore must be practised before you need it.

## What you will learn

After this module, you can:

- describe the routine that patches the operating system, kernel and container runtime of a node without losing the application;
- find and remove the leftovers of a maintenance window: a cordon, taints and Pods that cannot be scheduled;
- run a layered post-upgrade check of nodes, API health, system Pods, disruption budgets, deprecated API use and a real request;
- explain why Kubernetes has no downgrade path, and when to fix forward or restore etcd;
- plan etcd snapshots and restore drills, so that a restore works on the first real try.

## How the module is laid out

You start with **Patch The Operating System And Container Runtime On Nodes**. It shows the routine of drain, patch, reboot and return for one node, and what a window can leave behind. **Verify The Cluster After An Upgrade** then gives a layered check that goes from the nodes up to a real request. **Rollback Limits And Restore Drills** closes the module. It explains why a minor upgrade cannot be undone with a downgrade, when to restore etcd, and how to test a restore before you need it.

## Before you start

You should know the Kubernetes basics: Pods, Deployments, nodes, `kubectl cordon` and `kubectl drain`. You also need a little Linux: `sudo`, `apt` and `systemctl`.

## Your playground

Your playground is a virtual machine (VM) with Ubuntu 24.04. It runs a one-node Kubernetes 1.35 cluster that `kubeadm` installed. The node is called `controlplane`. It runs the control plane and the example workloads, and it uses `containerd` as its container runtime. Because the VM is a real host, you run every command of this module in it, including `apt`, `systemctl`, `etcdctl` and `etcdutl`.

Open a shell on the VM from your own machine:

```sh
astrona ssh astro-ats-032-playground-040-03
```

You are the user `student`. `kubectl` already works and has the `cluster-admin` role, and you can run host commands as root with `sudo`. The cluster starts with this content:

| Namespace | Object | What it is |
| --- | --- | --- |
| `starfleet` | `probe` Deployment, two replicas, labels `app: probe` and `release: probe` | A small Python web server that listens on port 8080 and answers with its version, host name and greeting |
| `starfleet` | `probe-code` ConfigMap | Holds the program `server.py` that the `probe` Pods run |
| `starfleet` | `probe` Service | Port 80, forwards to the `http` port (8080) of the `probe` Pods |
| `starfleet` | `shuttle` Pod, label `app: shuttle` | A client Pod with BusyBox tools such as `wget` |
| `outpost` | `drifter` Pod, label `app: drifter` | A client Pod with BusyBox tools, in another namespace |

`shuttle` and `drifter` are bare Pods: no controller, such as a Deployment, manages them. The setup also copied the etcd tools `etcdctl` and `etcdutl` out of the etcd image to `/usr/local/bin` on the node.

Launch your playground now, and keep it running next to you while you read:

<!-- astrona:playground -->
