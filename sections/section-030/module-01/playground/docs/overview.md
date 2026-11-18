---
exam_objectives:
- Restrict access to Kubernetes API
---
# Playground Guide

This playground is a private virtual machine (VM) for the module "Restrict Access To The Kubernetes API". It runs a single-node Kubernetes v1.35 cluster that `kubeadm` created, and it is separate from the lab environments. Nothing in it is graded, so you can change and break things freely.

## Connect

Open a shell on the VM from your own machine:

```sh
astrona ssh astro-ats-032-playground-030-01
```

You are the user `student`. You can run commands as root with `sudo`, and `kubectl` already works with the `cluster-admin` role. Run every command of the module in this shell. Check that `kubectl` talks to the playground cluster:

```sh
kubectl config current-context
kubectl get nodes
```

```text
kubernetes-admin@astro-ats-032-playground-030-01
NAME           STATUS   ROLES           AGE     VERSION
controlplane   Ready    control-plane   3m34s   v1.35.10
```

Your `AGE` value differs. The only node is `controlplane`. It runs the control plane (the API server, etcd, the controller manager and the scheduler as static Pods) and the example workloads.

## What is in the cluster

The namespace `starfleet` holds the Deployment `probe` with two replicas, its Service, and the Pod `shuttle`. The namespace `outpost` holds the Pod `drifter`. All of them use the `default` ServiceAccount of their namespace. The files that configure the cluster are on the node: the API server manifest is `/etc/kubernetes/manifests/kube-apiserver.yaml`, and the kubelet configuration is `/var/lib/kubelet/config.yaml`. Both belong to root, so read them with `sudo`.

## Practice tasks

1. Define the `call_api` helper and compare anonymous and token requests.
2. Create a ServiceAccount, Role and RoleBinding and run the `probe` Deployment as that account.
3. Send an allowed and a denied request from the Pod.
4. Print the live kube-apiserver flags and compare them with the hardening list.
5. Read the kubelet configuration, from the file and from the running kubelet, and send an anonymous request to port 10250.

The module text gives the exact commands for each task. Use `kubectl get` and `kubectl describe` to inspect any object you create, and delete the objects of a task when you finish it.

## Reset

If the cluster is in a state you cannot explain, destroy the playground and launch a new one. The cluster starts from the same content every time.
