---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Upgrade A kubeadm Control Plane From v1.35 To v1.36

Allow about 15 minutes for the tasks.

The `starfleet` cluster runs Kubernetes v1.35, and a security fix is only in v1.36. Upgrade its single control-plane node with `kubeadm`, and bring the `probe` workload back when you are done.

## Connect to the lab

The lab is a virtual machine (VM) with one Kubernetes node. Open a shell on it from your own machine:

```sh
astrona ssh astro-ats-032-lab-040-01-02
```

You are the user `student`. You can run commands as root with `sudo`, and `kubectl` already works for this cluster. The node is called `controlplane`. It is the only node, so it is both the control plane and the node that runs the workload.

The VM needs no internet access. The Kubernetes packages come from a local package repository with the same layout as `pkgs.k8s.io`: one repository for each minor version, in `/opt/kubernetes-apt/v1.35/deb/` and `/opt/kubernetes-apt/v1.36/deb/`. The file `/etc/apt/sources.list.d/kubernetes.list` names the v1.35 repository. All container images for both versions are already on the node.

## Tasks

1. Upgrade the control plane of the cluster to the newest v1.36 patch release with `kubeadm upgrade apply`. The API server, controller manager, scheduler and `kube-proxy` must run v1.36.
2. Upgrade the `kubeadm`, `kubelet` and `kubectl` packages to the same v1.36 release. All three packages must be on hold when you are done, so that `apt-mark showhold` lists them.
3. Drain the node `controlplane` before you upgrade the `kubelet`, restart the kubelet, and then make the node schedulable again. When you finish, `kubectl get nodes` must show `controlplane` as `Ready` with version v1.36, and the Deployment `probe` in the namespace `starfleet-032-040-01-02` must have all its replicas available.

## How the answer is checked

The grader runs three checks:

- The API server reports v1.36. The `kube-apiserver`, `kube-controller-manager` and `kube-scheduler` Pods on `controlplane` run v1.36 images and are Ready, the DaemonSet `kube-proxy` uses a v1.36 image, and the ConfigMap `kubeadm-config` records v1.36.
- The packages `kubeadm`, `kubelet` and `kubectl` are installed at a 1.36 version, and `apt-mark showhold` lists each of them.
- The node `controlplane` reports kubelet v1.36, is Ready and is not cordoned, and the Deployment `probe` has all its replicas available.

Any v1.36 patch release passes. The grader checks the end state, so it cannot prove that you drained the node before the kubelet restart.
