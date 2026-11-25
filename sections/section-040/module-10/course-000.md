---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Upgrade Kubernetes To Avoid Vulnerabilities

Kubernetes publishes security fixes only for the newest releases. A cluster that stays on an old version keeps every known flaw in that version, and the flaws are public. Upgrading is therefore a security control. It is also a risky operation, because it restarts the control plane and moves workloads off nodes. This module shows how to plan an upgrade that stays inside the supported version rules, how to empty a node safely, how to run the kubeadm upgrade, and how to protect and verify the cluster around it.

Keep one sentence in mind for this module: **upgrade one minor version at a time, control plane first, one node at a time, with a snapshot before and a check after.** You will read the versions of a live cluster, drain a node with a disruption budget in place, upgrade a kubeadm cluster from 1.35 to 1.36 command by command, and take the etcd snapshot that makes a failed upgrade recoverable.

The module has four parts. **Versions, Skew And Support** explains the release and support rules and how to read the versions of every component. **Cordon, Drain And Disruption Budgets** takes a node out of service and returns it. **The kubeadm Upgrade Sequence** upgrades the control-plane node and explains the steps for each other node. **Snapshot And Verify** covers the etcd snapshot before the upgrade and the checks after it.

## Learning objectives

After this module you can:

- State the version skew rules between the API server, kubelet, controller manager, scheduler and `kubectl`.
- Say why a cluster must be upgraded to keep receiving security fixes, and why minor versions cannot be skipped.
- Cordon, drain and uncordon a node, and explain how a PodDisruptionBudget limits a drain.
- Write the order and the commands of a kubeadm upgrade for a control-plane node and for a worker.
- Take and check an etcd snapshot, and verify the cluster after an upgrade.

## Before you start

You need Kubernetes basics: Pods, Deployments, Services, nodes and `kubectl`. You also need a Linux shell and `sudo`, because the upgrade and the etcd snapshot run on the host, not only through `kubectl`. Every part runs its commands on the playground.

The playground is a private virtual machine (VM) with Ubuntu 24.04. `kubeadm`, the Kubernetes tool that installs and upgrades a cluster on hosts you manage, created a one-node Kubernetes 1.35 cluster on it. The VM also holds the packages for 1.36, so you can run a real upgrade without the internet. Open a shell on it from your own machine:

```sh
astrona ssh astro-ats-032-playground-040-01
```

You are the user `student`. You can run commands as root with `sudo`, and `kubectl` already works with full administrator rights. The only node is `controlplane`. It runs the control plane and the workloads. The cluster starts with this content:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The Deployment `probe` with two replicas and a Service `probe`, and the Pod `shuttle`, a client with BusyBox tools |
| `outpost` | The Pod `drifter`, a client with BusyBox tools |

`shuttle` and `drifter` are bare Pods: no controller owns them. The upgrade changes the cluster for good. Work through the parts in order, so that you read the 1.35 versions before you upgrade to 1.36.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
