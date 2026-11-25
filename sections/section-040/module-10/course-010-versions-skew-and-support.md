---
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

The rules only help if you know what runs. Open a shell on the playground with `astrona ssh astro-ats-032-playground-040-01` and start with the client and the server. `kubectl version` prints the version of `kubectl` itself and the version that the API server reports:

<!-- astrona:playground:renew -->

```sh
kubectl version
```

The playground printed:

```text
Client Version: v1.35.10
Kustomize Version: v5.7.1
Server Version: v1.35.10
```

The client and the server are on the same version, which is inside the skew of one minor version. Kustomize is a tool built into `kubectl`, and its version is not a Kubernetes version. The server version is the version of the API server. The kubelet on each node can still differ, so list the nodes next:

```sh
kubectl get nodes -o wide
```

```text
NAME           STATUS   ROLES           AGE   VERSION    INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
controlplane   Ready    control-plane   57s   v1.35.10   10.0.2.15     <none>        Ubuntu 24.04.5 LTS   6.8.0-149-generic   containerd://2.2.1
```

The `VERSION` column is the version of the kubelet on that node, and the last column is the container runtime. The playground has one node. In a cluster with many nodes, all nodes show the same value when no upgrade is in progress. The control-plane components run as Pods in `kube-system`, and their image tags are their versions:

```sh
kubectl -n kube-system get pods -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[*].image
```

```text
NAME                                   IMAGE
coredns-7d764666f9-kgspt               registry.k8s.io/coredns/coredns:v1.13.1
coredns-7d764666f9-mjqbv               registry.k8s.io/coredns/coredns:v1.13.1
etcd-controlplane                      registry.k8s.io/etcd:3.6.6-0
kube-apiserver-controlplane            registry.k8s.io/kube-apiserver:v1.35.10
kube-controller-manager-controlplane   registry.k8s.io/kube-controller-manager:v1.35.10
kube-proxy-plpdt                       registry.k8s.io/kube-proxy:v1.35.10
kube-scheduler-controlplane            registry.k8s.io/kube-scheduler:v1.35.10
```

The Pods `kube-apiserver`, `kube-controller-manager`, `kube-scheduler` and `kube-proxy` all show `v1.35.10`. The `etcd` image (`3.6.6-0`) and the `coredns` image (`v1.13.1`) have their own version numbers, which are not Kubernetes versions. Your Pod names end in other random letters.

On a kubeadm cluster, the `kubeadm` tool has a version too. `kubeadm version` on the node prints it, and here it is `v1.35.10`. Before an upgrade, `kubeadm upgrade plan` lists the versions that you can upgrade to.

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
