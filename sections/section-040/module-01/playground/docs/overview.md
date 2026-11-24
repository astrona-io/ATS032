---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Playground Guide

This playground is a private virtual machine (VM) with Ubuntu 24.04 and a one-node Kubernetes 1.35 cluster that `kubeadm` created. `kubeadm` is the Kubernetes tool that installs and upgrades a cluster on hosts you manage. The VM is separate from the lab VMs. Nothing in it is graded, so you can change and break things freely.

## Connect

Open a shell on the VM from your own machine:

```sh
astrona ssh astro-ats-032-playground-040-01
```

You are the user `student`. You can run commands as root with `sudo`, and `kubectl` already works with full administrator rights on the cluster. Check that you reach the right cluster:

```sh
kubectl config current-context
kubectl get nodes
```

The context is `kubernetes-admin@astro-ats-032-playground-040-01`. The only node is `controlplane`. It runs the control plane and your workloads, because the node has no control-plane taint. Open a new shell with the same `astrona ssh` command whenever you need one.

## What is on the VM

The namespace `starfleet` holds the Deployment `probe` with two replicas, its Service `probe`, and the Pod `shuttle`. The namespace `outpost` holds the Pod `drifter`. `shuttle` and `drifter` are bare Pods with BusyBox tools: no controller owns them.

The host has the tools of a kubeadm control-plane node. `kubeadm`, `kubelet` and `kubectl` are installed from a Kubernetes package repository on the VM, under `/opt/kubernetes-apt`, and the packages are on hold. The image also holds the package `falco`, a runtime security tool that watches system calls, so `apt-mark showhold` lists four packages. That repository has the packages for 1.35 and 1.36, so you can upgrade the cluster to 1.36 without the internet. `etcdctl` and `etcdutl`, the etcd client and the etcd file tool, are in `/usr/local/bin`. The etcd certificates are under `/etc/kubernetes/pki/etcd/`.

## Practice tasks

1. Read the client, server and node versions, and the image of each control-plane Pod.
2. Create a PodDisruptionBudget for `probe`, try to drain `controlplane`, and uncordon it again.
3. Upgrade the cluster from 1.35 to 1.36 with `kubeadm`.
4. Save an etcd snapshot, check it with `etcdutl`, and verify the cluster after the upgrade.

The course text gives the exact commands for each task, in this order. The upgrade in task 3 cannot be undone on this VM, so do task 1 first.

## Reset

If the cluster is in a state you cannot explain, destroy the playground and launch a new one. It starts again at 1.35 with the same content.
