---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Solution: Upgrade A kubeadm Control Plane From v1.35 To v1.36

`kubeadm` is the tool that created this cluster. `kubeadm upgrade apply` upgrades the control-plane components, which run as static Pods: Pods that the kubelet starts from manifest files in `/etc/kubernetes/manifests`, not from the API server. It does not upgrade the `kubelet` or `kubectl` packages. You upgrade those with `apt`, the package manager of Ubuntu. The order is: `kubeadm` first, then `kubeadm upgrade plan` and `apply`, then drain, `kubelet` and `kubectl`, restart the kubelet, and uncordon.

## Step 1: Look at the starting state

Connect with `astrona ssh astro-ats-032-lab-040-01-02`. Check the node version, the workload and the held packages:

```sh
kubectl get nodes
kubectl -n starfleet-032-040-01-02 get pods
apt-mark showhold
cat /etc/apt/sources.list.d/kubernetes.list
```

The node runs v1.35.10, the two `probe` Pods run on it, and the three packages are on hold. The package source names the v1.35 repository:

```text
NAME           STATUS   ROLES           AGE     VERSION
controlplane   Ready    control-plane   3m28s   v1.35.10
NAME                     READY   STATUS    RESTARTS   AGE
probe-5dbf7f459d-4n5tc   1/1     Running   0          3m12s
probe-5dbf7f459d-6cmtk   1/1     Running   0          3m11s
kubeadm
kubectl
kubelet
deb [signed-by=/etc/apt/keyrings/astrona-kubernetes-local.gpg] file:/opt/kubernetes-apt/v1.35/deb/ /
```

## Step 2: Point apt at the v1.36 repository

Each minor version has its own repository, so you change `v1.35` to `v1.36` in the package source. Then `apt-get update` reads the new package list, and `apt-cache madison` shows the exact version to install:

```sh
sudo sed -i 's#/v1.35/#/v1.36/#' /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
apt-cache madison kubeadm
```

The last command prints one line for the v1.36 package:

```text
   kubeadm | 1.36.6-1.1 | file:/opt/kubernetes-apt/v1.36/deb  Packages
```

If the VM has no internet access, `apt-get update` also prints warnings for the Ubuntu archive. The local Kubernetes repository still works. Use the version from your own `madison` output in the next steps, if it differs from `1.36.6-1.1`.

## Step 3: Upgrade kubeadm

A held package is never changed by `apt-get install`, so remove the hold, install the new `kubeadm` and hold it again:

```sh
sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm=1.36.6-1.1
sudo apt-mark hold kubeadm
kubeadm version -o short
```

The last command prints `v1.36.6`. `kubeadm` itself is now new, but the cluster still runs v1.35.

## Step 4: Plan and apply the control-plane upgrade

`kubeadm upgrade plan` checks the health of the cluster and shows what `apply` would change:

```sh
sudo kubeadm upgrade plan
```

The important part of the output is the table of components and the command to run (shortened here):

```text
[upgrade/versions] Cluster version: 1.35.10
[upgrade/versions] kubeadm version: v1.36.6
[upgrade/versions] Target version: v1.36.6
[upgrade/versions] Latest version in the v1.35 series: v1.35.10

Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   NODE           CURRENT    TARGET
kubelet     controlplane   v1.35.10   v1.36.6

Upgrade to the latest stable version:

COMPONENT                 NODE           CURRENT    TARGET
kube-apiserver            controlplane   v1.35.10   v1.36.6
kube-controller-manager   controlplane   v1.35.10   v1.36.6
kube-scheduler            controlplane   v1.35.10   v1.36.6
kube-proxy                               1.35.10    v1.36.6
CoreDNS                                  v1.13.1    v1.14.2
etcd                      controlplane   3.6.6-0    3.6.8-0

You can now apply the upgrade by executing the following command:

	kubeadm upgrade apply v1.36.6
```

The first table says that `kubeadm` will not upgrade the `kubelet`; you do that in the next step. Now apply the upgrade. `--yes` answers the confirmation question:

```sh
sudo kubeadm upgrade apply v1.36.6 --yes
```

The command takes two to three minutes. It writes new static Pod manifests, waits for each component to restart, and upgrades CoreDNS and `kube-proxy`. It ends with:

```text
[upgrade] SUCCESS! A control plane node of your cluster was upgraded to "v1.36.6".
```

The API server now runs v1.36, but the node still shows the old kubelet version:

```text
NAME           STATUS   ROLES           AGE     VERSION
controlplane   Ready    control-plane   6m32s   v1.35.10
```

## Step 5: Drain the node

Drain moves the workload off the node before the kubelet restarts. `--ignore-daemonsets` is needed because a DaemonSet Pod, such as `kube-proxy`, cannot move to another node:

```sh
kubectl drain controlplane --ignore-daemonsets
kubectl get nodes
```

The output shows the node cordoned and the Pods evicted:

```text
node/controlplane cordoned
evicting pod starfleet-032-040-01-02/probe-5dbf7f459d-6cmtk
evicting pod kube-system/coredns-7d764666f9-fdnqs
evicting pod kube-system/coredns-7d764666f9-dxzck
evicting pod starfleet-032-040-01-02/probe-5dbf7f459d-4n5tc
pod/probe-5dbf7f459d-4n5tc evicted
pod/probe-5dbf7f459d-6cmtk evicted
pod/coredns-7d764666f9-dxzck evicted
pod/coredns-7d764666f9-fdnqs evicted
node/controlplane drained
NAME           STATUS                     ROLES           AGE     VERSION
controlplane   Ready,SchedulingDisabled   control-plane   6m44s   v1.35.10
```

`kubectl drain` can also print a warning that it ignores the `kube-proxy` Pod, which belongs to a DaemonSet. Both forms are normal.

This cluster has only one node, so the new `probe` Pods stay `Pending` until you uncordon the node. In a cluster with more nodes they would start on another node.

## Step 6: Upgrade kubelet and kubectl, then restart the kubelet

Install both packages with the same version as `kubeadm`, and hold them again. `systemctl daemon-reload` makes systemd read the unit files that the new package may have changed, and the restart starts the new kubelet:

```sh
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet=1.36.6-1.1 kubectl=1.36.6-1.1
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
kubectl get nodes
```

After a few seconds the node reports the new kubelet, and it is still cordoned:

```text
NAME           STATUS                     ROLES           AGE     VERSION
controlplane   Ready,SchedulingDisabled   control-plane   7m22s   v1.36.6
```

Right after the restart, `kubectl` can print `Error from server (Forbidden): nodes is forbidden: User "kubernetes-admin" cannot list resource "nodes"` or `The connection to the server 10.0.2.15:6443 was refused`. The kubelet is starting the API server Pod again, and the API server is not ready yet. Wait ten seconds and run the command again.

## Step 7: Uncordon the node and check the result

Make the node schedulable again, so that the `probe` Pods can start:

```sh
kubectl uncordon controlplane
kubectl get nodes
kubectl -n starfleet-032-040-01-02 get pods
apt-mark showhold
```

The node is `Ready` at v1.36.6, both `probe` Pods run, and all three packages are on hold:

```text
node/controlplane uncordoned
NAME           STATUS   ROLES           AGE     VERSION
controlplane   Ready    control-plane   7m43s   v1.36.6
NAME                     READY   STATUS    RESTARTS   AGE
probe-5dbf7f459d-b9hpc   1/1     Running   0          66s
probe-5dbf7f459d-znv8z   1/1     Running   0          66s
kubeadm
kubectl
kubelet
```

`kubectl version` confirms that the client and the API server both run v1.36.6:

```text
Client Version: v1.36.6
Kustomize Version: v5.8.1
Server Version: v1.36.6
```

The cluster now runs v1.36 on every component, and the packages are on hold again. A routine `apt-get upgrade` therefore cannot change the Kubernetes version by accident.
