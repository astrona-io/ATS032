---
exam_objectives:
- Restrict access to Kubernetes API
---
# Playground Guide

This playground is a private virtual machine (VM) with a Kubernetes 1.35 cluster that `kubeadm` created, for the module "Authentication, Anonymous Access And Authorization Modes". It is separate from the lab VMs. Nothing in it is graded, so you can change and break things freely.

## Connect

Open a shell on the VM from your own machine:

```sh
astrona ssh astro-ats-032-playground-030-02
```

You are the user `student`. You can run commands as root with `sudo`, and `kubectl` already works for this cluster. Its credentials belong to the user `kubernetes-admin`, which has the `cluster-admin` role. Run every command in that shell. Open a new shell the same way whenever you need one.

The cluster has one node, called `controlplane`. It runs the control plane and the example workloads. The kubelet on it runs the API server as a static Pod from `/etc/kubernetes/manifests/kube-apiserver.yaml`, and only root can read or change that file. The VM needs no internet access: every image the cluster uses is already on the node.

## What is in the cluster

The namespace `starfleet` holds the Deployment `probe` with two replicas, its Service, and the pod `shuttle`. The namespace `outpost` holds the pod `drifter`. All of them use the default ServiceAccount of their namespace. Two ClusterRoleBindings exist: `anonymous-viewer` gives `view` to the group `system:unauthenticated`, and `ops-viewer` gives `view` to the group `ops`.

## Practice tasks

1. Read your own identity with `kubectl auth whoami` and decode a ServiceAccount token.
2. Define the `call_api` helper and compare anonymous, token and invalid-token requests.
3. Find the binding that lets anonymous callers list Pods and delete it.
4. Read the live `--authorization-mode` flag, read the same flag in the API server manifest with `sudo`, and test an identity with `--as`.

The module text gives the exact commands for each task. Use `kubectl get` and `kubectl describe` to inspect any object you create, and delete the objects of a task when you finish it.

## Reset

If the cluster is in a state you cannot explain, for example after an edit of the API server manifest that stops the API server, destroy the playground and launch a new one. The cluster starts from the same content every time.
