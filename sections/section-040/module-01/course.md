---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Upgrade Kubernetes To Avoid Vulnerabilities

Kubernetes publishes security fixes only for the newest releases. A cluster that stays on an old version keeps every known flaw in that version, and the flaws are public. Upgrading is therefore a security control. It is also a risky operation, because it restarts the control plane and moves workloads off nodes. This module shows how to plan an upgrade that stays inside the supported version rules, how to empty a node safely, how to run the kubeadm upgrade, and how to protect and verify the cluster around it.

Keep one sentence in mind for this module: **upgrade one minor version at a time, control plane first, one node at a time, with a snapshot before and a check after.** You will read the versions of a live cluster, drain and return a worker with a disruption budget in place, read through the kubeadm upgrade sequence command by command, and learn the etcd snapshot that makes a failed upgrade recoverable.

The module has four parts. **Versions, Skew And Support** explains the release and support rules and how to read the versions of every component. **Cordon, Drain And Disruption Budgets** takes a worker out of service and returns it. **The kubeadm Upgrade Sequence** lists the commands for the control-plane node and each worker. **Snapshot And Verify** covers the etcd snapshot before the upgrade and the checks after it.

## Learning objectives

After this module you can:

- State the version skew rules between the API server, kubelet, controller manager, scheduler and `kubectl`.
- Say why a cluster must be upgraded to keep receiving security fixes, and why minor versions cannot be skipped.
- Cordon, drain and uncordon a node, and explain how a PodDisruptionBudget limits a drain.
- Write the order and the commands of a kubeadm upgrade for a control-plane node and for a worker.
- Take and check an etcd snapshot, and verify the cluster after an upgrade.

## Before you start

You need Kubernetes basics: Pods, Deployments, Services, nodes and `kubectl`. Parts one and two run against a playground. Parts three and four contain commands for hosts that are installed with `kubeadm`. The playground is a `kind` cluster, whose nodes are containers, so those host commands are shown for you to read and are not run in it.

Your terminal must use the playground's private kubeconfig, the file that holds the cluster address and credentials for `kubectl`. Run these two commands once in every new terminal:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-040-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-040-01" || exit 1
```

The playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and two workers. Your own credentials have the `cluster-admin` role. The cluster starts with this content:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The Deployment `probe` with two replicas and a Service `probe`, and the Pod `shuttle`, a client with BusyBox tools. `shuttle` runs on the second worker |
| `outpost` | The Pod `drifter`, a client with BusyBox tools. It runs on the second worker |

The nodes are named `astro-ats-032-playground-040-01-control-plane`, `astro-ats-032-playground-040-01-worker` and `astro-ats-032-playground-040-01-worker2`.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
