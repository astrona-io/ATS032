---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Playground Guide

This playground is a private virtual machine (VM) for the module "Patch Nodes And Verify The Upgraded Cluster". It runs Ubuntu 24.04 and a one-node Kubernetes 1.35 cluster that `kubeadm` installed. It is separate from the lab VMs. Nothing in it is graded, so you can change and break things freely.

## Connect

Open a shell on the VM from your own machine:

```sh
astrona ssh astro-ats-032-playground-040-03
```

You are the user `student`. `kubectl` already works and has the `cluster-admin` role. Run host commands such as `apt`, `systemctl`, `etcdctl` and `etcdutl` with `sudo`. Check that you are on the right cluster before you change anything:

```sh
kubectl get nodes
```

The output lists one node, `controlplane`.

## What is in the cluster

The node `controlplane` runs the control plane and the workloads, with `containerd` as its container runtime. The namespace `starfleet` holds the Deployment `probe` with two replicas, its Service `probe`, and the Pod `shuttle`. The namespace `outpost` holds the Pod `drifter`. `shuttle` and `drifter` are bare Pods with BusyBox tools; no controller manages them. The bootstrap copied `etcdctl` and `etcdutl` out of the etcd image to `/usr/local/bin`, so you can use them on the host.

## Practice tasks

1. Read the operating system, kernel and runtime of the node, and simulate an `apt` upgrade.
2. Cordon the node and add a taint for a pretend patch window, then undo both.
3. Drain the `probe` Pods, restart `containerd` with `systemctl` and return the node to service.
4. Run the layered post-upgrade checks: node, API health, system Pods, budgets and an application request.
5. Take an etcd snapshot and restore it into a separate data directory.

The module text gives the exact commands for each task. Use `kubectl get` and `kubectl describe` to inspect any object you create, and delete the objects of a task when you finish it.

## Reset

If the cluster is in a state you cannot explain, destroy the playground and launch a new one. The VM starts from the same content every time.
