# Upgrade Kubernetes To Avoid Vulnerabilities

Kubernetes publishes security fixes only for its newest releases. A cluster that stays on an old version keeps every known flaw of that version, and those flaws are public. So an upgrade is a security control, just like a firewall rule or a role binding.

An upgrade is also a risky operation. It restarts the control plane, and it moves workloads off each node while that node changes. A careless upgrade can take an application down or leave the cluster in a broken state.

This module shows how to do it safely. You plan an upgrade that stays inside the supported version rules, empty a node without losing the application, run the kubeadm upgrade, and protect and check the cluster before and after.

Keep one sentence in mind while you read: **upgrade one minor version at a time, control plane first, one node at a time, with a snapshot before and a check after.**

## What you will learn

After this module, you can:

- state the version skew rules between the API server, kubelet, controller manager, scheduler and `kubectl`;
- explain why a cluster must be upgraded to keep receiving security fixes, and why minor versions cannot be skipped;
- cordon, drain and uncordon a node, and explain how a PodDisruptionBudget limits a drain;
- write the order and the commands of a kubeadm upgrade for a control-plane node and for a worker;
- take and check an etcd snapshot, and verify the cluster after an upgrade.

## How the module is laid out

You start with **Versions, Skew And Support**, which explains the release and support rules and shows how to read the version of every component in a live cluster. **Cordon, Drain And Disruption Budgets** then takes a node out of service, with a disruption budget in place, and returns it.

**The kubeadm Upgrade Sequence** upgrades the playground cluster from Kubernetes 1.35 to 1.36, command by command, and explains the steps for every other node. **Snapshot And Verify** closes the module with the etcd snapshot that makes a failed upgrade recoverable, and the checks that prove the cluster works afterwards.

Labs follow the parts they practise, so you can use each skill right away.

## Before you start

You should know the Kubernetes basics: Pods, Deployments, Services, nodes and `kubectl`. You also need a Linux shell and `sudo`, because the upgrade and the etcd snapshot run on the host, not only through `kubectl`. Every part runs its commands on the playground.

## Your playground

The playground is a private virtual machine (VM) with Ubuntu 24.04. `kubeadm` is the Kubernetes tool that installs and upgrades a cluster on hosts you manage. It created a one-node Kubernetes 1.35 cluster on the VM. The VM also holds the packages for 1.36, so you can run a real upgrade without the internet. Open a shell on it from your own machine:

```sh
astrona ssh astro-ats-032-playground-040-01
```

You are the user `student`. You can run commands as root with `sudo`, and `kubectl` already works with full administrator rights. The only node is `controlplane`. It runs the control plane and the workloads. The cluster starts with this content:

| Namespace | Object | What it is |
| --- | --- | --- |
| `starfleet` | `probe` Deployment, two replicas, label `app: probe` | A small Python web server that listens on port 8080 and answers with its version, its Pod name and a greeting |
| `starfleet` | `probe-code` ConfigMap | Holds the program of the `probe` web server |
| `starfleet` | `probe` Service | Port 80, forwards to port 8080 of the `probe` Pods |
| `starfleet` | `shuttle` Pod, label `app: shuttle` | A bare client Pod with BusyBox tools |
| `outpost` | `drifter` Pod, label `app: drifter` | A bare client Pod with BusyBox tools, in another namespace |

`shuttle` and `drifter` are bare Pods, which means that no controller owns them. The host also has `etcdctl` and `etcdutl`, the etcd client and the etcd file tool, in `/usr/local/bin`.

The upgrade changes the cluster for good. Work through the parts in order, so that you read the 1.35 versions before you upgrade to 1.36.

Start your playground now, and keep it running next to you while you read:

<!-- astrona:playground -->
