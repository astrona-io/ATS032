---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Versions, Skew And Support

Before you change anything in a cluster, you need to know what runs and what the rules allow. This part explains the version numbers, which releases receive fixes, how far apart the components may be, and how to read the versions of a live cluster.

## Version numbers and support

A Kubernetes version has the form `v1.35.2`. The middle number is the **minor** version and the last number is the **patch** version. A new minor version is released about three times a year. Patch releases come more often and carry bug and security fixes.

The project keeps release branches for the most recent three minor versions. A minor version that falls out of that window gets no more fixes, even for a published vulnerability. A cluster on such a version can only be protected by upgrading. A patch upgrade inside one minor version is low risk and should be applied quickly. A minor upgrade changes behavior and must be planned. Read the release notes for removed APIs and changed defaults before you start.

## Version skew

During an upgrade, components run different versions for a while. Kubernetes states which differences are supported. For a cluster at version 1.35, the rules are:

| Component | Supported relation to `kube-apiserver` |
| --- | --- |
| Other `kube-apiserver` instances in a high-availability control plane | Up to one minor version older |
| `kube-controller-manager`, `kube-scheduler`, `cloud-controller-manager` | The same version or up to one minor older. Never newer |
| `kubelet` | The same version or up to three minor versions older. Never newer |
| `kube-proxy` | The same version or up to three minor versions older, and not newer than the kubelet on the same node |
| `kubectl` | One minor version older or newer |

The consequence is the upgrade order: the API server first, then the controller manager, scheduler and the other control-plane components, then the kubelets. The API server must never be older than a component that talks to it. The kubelet allowance of three minor versions gives time to upgrade nodes in groups. Skipping a minor version of the control plane is not supported. To go from 1.33 to 1.35, upgrade to 1.34 and then to 1.35.

## Read the versions of a live cluster

The first command prints the client and server versions. The second lists the nodes with the version of each kubelet, the operating system and the container runtime. The third lists the images of the control-plane Pods in `kube-system`.

<!-- astrona:playground:renew -->

```sh
kubectl version
kubectl get nodes -o wide
kubectl -n kube-system get pods -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[*].image
```

In the output of `kubectl version`, compare the client version with the server version. They must be within one minor version of each other. In the node list, the `VERSION` column shows the kubelet version of each node, and in a healthy cluster all nodes show the same value. In the image list, the control-plane Pods `kube-apiserver`, `kube-controller-manager`, `kube-scheduler` and `kube-proxy` show their image tags, and these tags are the component versions. The `etcd` and `coredns` images have their own version numbers, which are not Kubernetes versions.

For a kubeadm cluster, `kubeadm version` on a node shows the version of the tool itself, and `kubeadm upgrade plan` shows the versions it can upgrade to. Both are covered in a later part.

## Plan the upgrade

Write down four things before you start.

1. The current version of every component and the target version. The target is the next minor version, or the newest patch of the current one.
2. The maintenance window and the order of nodes. Upgrade the control plane first, then workers one at a time or in small groups.
3. The workloads that must not lose availability and their PodDisruptionBudgets.
4. The way back: a fresh etcd snapshot and a copy of the cluster configuration.

You now know how to find the versions that run, which ones may differ, and what the upgrade order is. The next step is to take a node out of service without losing the application.

## Common pitfalls

> [!WARNING]
> - **Skipping a minor version.** The control plane supports upgrades one minor version at a time.
> - **Upgrading a kubelet before the API server.** The kubelet may not be newer than the API server.
> - **Treating the `etcd` or `coredns` image tag as the Kubernetes version.** They have their own numbering.
> - **Running a client more than one minor version away from the server.** Some calls fail or behave in unexpected ways.
> - **Staying on a minor version that is out of the support window.** It no longer receives fixes for new vulnerabilities.
