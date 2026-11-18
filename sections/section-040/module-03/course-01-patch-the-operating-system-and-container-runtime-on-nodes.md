---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Patch The Operating System And Container Runtime On Nodes

The `kubelet` and the control-plane components are only part of a node. Below them run the operating system, the kernel and the container runtime, and attackers use flaws in all three. A Kubernetes upgrade does not fix them. This part shows what to patch on a node, the rotation that keeps the application available, and the leftovers a maintenance window can leave behind.

## What lives on a node

A node is a host with four layers that need patches. The **operating system packages** include system libraries and tools such as `openssl`. The **kernel** is the core of the operating system; every container on the node shares it, so a kernel flaw can let a process escape its container. The **container runtime** (`containerd` in most clusters) starts and stops containers. The **Kubernetes node packages** are `kubelet`, `kubeadm` and `kubectl`.

The first three layers are patched with the distribution's tools. The last is patched with the upgrade procedure. A security policy has to cover both groups, because a cluster with a perfect Kubernetes version can still be taken over through an old kernel.

## Read what a node runs

The node object shows the operating system image, the kernel and the runtime version. Read them for every node before and after a patch, so that the change is visible. On the host, `uname -r` prints the running kernel and `containerd --version` prints the runtime binary:

<!-- astrona:playground:renew -->

```sh
kubectl get nodes -o custom-columns=NAME:.metadata.name,OS:.status.nodeInfo.osImage,KERNEL:.status.nodeInfo.kernelVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion
uname -r
containerd --version
```

```text
NAME           OS                   KERNEL              RUNTIME
controlplane   Ubuntu 24.04.5 LTS   6.8.0-149-generic   containerd://2.2.1
6.8.0-149-generic
containerd github.com/containerd/containerd/v2 2.2.1
```

The kubelet reports the same kernel and runtime that the host shows. Compare each value with the fixed version of a security advisory. The kernel version changes only after a reboot. This is why a patched kernel can still run the old version: the package is new, but the running kernel is the one that booted.

## The rotation

The safe routine patches one node at a time, in the order of the patch waves, and it repeats the same steps for each node.

```mermaid
flowchart TB
    A["Cordon and drain the node"] -->|"no workload left"| B["Patch packages and runtime"]
    B -->|"kernel changed"| C["Reboot"]
    C -->|"node Ready"| D["Uncordon"]
    D -->|"Pods return"| E["Check, then next node"]
```

The diagram shows the order within one node. The check at the end decides whether the next node starts.

On Debian or Ubuntu hosts, the package manager `apt` patches the packages. `apt-get update` reads the package lists, `apt-mark showhold` lists the packages that are held at their version, and `apt-get upgrade --simulate` prints what an upgrade would change without changing anything:

```sh
sudo apt-get update
apt-mark showhold
sudo apt-get upgrade --simulate
test -f /var/run/reboot-required && echo reboot needed
```

The output of `apt-get update` is a list of package sources and is left out here. If the VM has no network, it only prints warnings, and the simulation uses the lists it already has. The rest of the output in this run was:

```text
kubeadm
kubectl
kubelet
Reading package lists...
Building dependency tree...
Reading state information...
Calculating upgrade...
The following packages will be upgraded:
  needrestart
1 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
Inst needrestart [3.6-7ubuntu4.5] (3.6-7ubuntu4.6 Ubuntu:24.04/noble-updates, Ubuntu:24.04/noble-security [all])
Conf needrestart (3.6-7ubuntu4.6 Ubuntu:24.04/noble-updates, Ubuntu:24.04/noble-security [all])
```

The three Kubernetes packages are held, so `apt-get upgrade` leaves them on their version; the upgrade procedure moves them. The last command printed nothing, because the marker file `/var/run/reboot-required` does not exist. Ubuntu creates it after a kernel or core library update. When it exists, you run `sudo systemctl reboot` on the drained node. After the reboot, the kubelet starts again and the node becomes Ready.

Some teams skip in-place patching. They create a new node from a newer image, add it to the cluster, drain the old node and delete it. This is called node replacement. It gives the same result as patching and the nodes stay identical, but it needs automation to create nodes.

## Automatic reboots

Unattended security updates install patches without a person. They are good for packages, but a kernel update still needs a reboot, and an unplanned reboot takes down every Pod on the node at once. A reboot controller such as Kured solves this. It watches for the reboot marker file, takes a lock so that only one node reboots at a time, drains the node, reboots it and uncordons it. Whatever tool you use, the rules are the same: one node at a time, drained first, and a disruption budget in place.

## Practise the maintenance state

A window puts a node into states that you can see with `kubectl`. Start with a taint, which is a key, value and effect on a node that keeps Pods away unless they tolerate it. The effect `NoSchedule` stops new Pods and keeps the running ones. Cordon the node and add a taint:

```sh
kubectl cordon controlplane
kubectl taint nodes controlplane maintenance=patching:NoSchedule
kubectl get nodes
kubectl describe node controlplane | grep -i -A2 taints
```

```text
node/controlplane cordoned
node/controlplane tainted
NAME           STATUS                     ROLES           AGE   VERSION
controlplane   Ready,SchedulingDisabled   control-plane   33s   v1.35.10
Taints:             maintenance=patching:NoSchedule
                    node.kubernetes.io/unschedulable:NoSchedule
Unschedulable:      true
```

The node shows `Ready,SchedulingDisabled`. Cordon sets the field `unschedulable` and also adds its own taint named `node.kubernetes.io/unschedulable`, so the description lists both taints. Now undo the work in two steps, and look at the result after the first step:

```sh
kubectl uncordon controlplane
kubectl describe node controlplane | grep -i -A2 taints
```

```text
node/controlplane uncordoned
Taints:             maintenance=patching:NoSchedule
Unschedulable:      false
Lease:
```

The node is schedulable again, but the taint `maintenance=patching:NoSchedule` is still there. Uncordon clears only the unschedulable flag, and the node controller then removes its own taint. A new Pod that does not tolerate the custom taint cannot run on the node. Remove the taint with a trailing minus sign:

```sh
kubectl taint nodes controlplane maintenance=patching:NoSchedule-
kubectl describe node controlplane | grep -i -A2 taints
```

```text
node/controlplane untainted
Taints:             <none>
Unschedulable:      false
Lease:
```

The node is back to normal. The next step is to empty a node before you change its runtime.

## Drain the node and restart the runtime

`kubectl drain` cordons the node and then asks the API server to evict each Pod on it. An eviction is a delete that respects disruption budgets. The controller of each Pod, for example the ReplicaSet of a Deployment, creates a replacement Pod. `--ignore-daemonsets` skips Pods of a DaemonSet, such as `kube-proxy`, because their controller would put them straight back:

```sh
kubectl drain controlplane --ignore-daemonsets
kubectl get nodes
```

```text
node/controlplane cordoned
error: unable to drain node "controlplane" due to error: cannot delete cannot delete Pods that declare no controller (use --force to override): outpost/drifter, starfleet/shuttle, continuing command...
There are pending nodes to be drained:
 controlplane
cannot delete cannot delete Pods that declare no controller (use --force to override): outpost/drifter, starfleet/shuttle
NAME           STATUS                     ROLES           AGE   VERSION
controlplane   Ready,SchedulingDisabled   control-plane   38s   v1.35.10
```

The drain stopped with exit code 1 and evicted nothing. `shuttle` and `drifter` are bare Pods: no controller would create them again, so `kubectl` refuses to delete them unless you add `--force`, and then they are gone for good. The node stays cordoned. In a real window, you give such Pods a controller or accept their loss.

In this playground, keep the clients and drain only the `probe` Pods. `--pod-selector` limits the drain to Pods with a matching label:

```sh
kubectl drain controlplane --ignore-daemonsets --pod-selector=app=probe --timeout=120s
kubectl get pods -A -o wide --field-selector=metadata.namespace!=kube-system
```

```text
node/controlplane already cordoned
evicting pod starfleet/probe-7db6ffd7d6-cbghl
evicting pod starfleet/probe-7db6ffd7d6-98rng
pod/probe-7db6ffd7d6-cbghl evicted
pod/probe-7db6ffd7d6-98rng evicted
node/controlplane drained
NAMESPACE   NAME                     READY   STATUS    RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
outpost     drifter                  1/1     Running   0          56s   10.244.0.7   controlplane   <none>           <none>
starfleet   probe-7db6ffd7d6-9sdkb   0/1     Pending   0          31s   <none>       <none>         <none>           <none>
starfleet   probe-7db6ffd7d6-wjxpv   0/1     Pending   0          31s   <none>       <none>         <none>           <none>
starfleet   shuttle                  1/1     Running   0          57s   10.244.0.6   controlplane   <none>           <none>
```

The ReplicaSet created two new `probe` Pods. They stay `Pending`, because the scheduler has no schedulable node. In a cluster with several nodes they would start on another node, and that is why you patch one node of several at a time.

Now restart the runtime. `systemd` is the service manager of Ubuntu, and `systemctl` talks to it. Read the process ID (`MainPID`) and the start time before and after the restart, so that you can prove the restart happened. Then wait for the node to be Ready, uncordon it and wait for the Deployment:

```sh
systemctl show containerd --property=MainPID --property=ActiveEnterTimestamp
sudo systemctl restart containerd
systemctl is-active containerd
systemctl show containerd --property=MainPID --property=ActiveEnterTimestamp
kubectl -n starfleet get pod shuttle
kubectl wait --for=condition=Ready node/controlplane --timeout=180s
kubectl uncordon controlplane
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n starfleet get pods -o wide
```

```text
MainPID=840
ActiveEnterTimestamp=Wed 2026-11-18 09:02:40 UTC
active
MainPID=3666
ActiveEnterTimestamp=Wed 2026-11-18 09:04:02 UTC
NAME      READY   STATUS    RESTARTS   AGE
shuttle   1/1     Running   0          57s
node/controlplane condition met
node/controlplane uncordoned
Waiting for deployment "probe" rollout to finish: 0 of 2 updated replicas are available...
Waiting for deployment "probe" rollout to finish: 1 of 2 updated replicas are available...
deployment "probe" successfully rolled out
NAME                     READY   STATUS    RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
probe-7db6ffd7d6-9sdkb   1/1     Running   0          32s   10.244.0.9   controlplane   <none>           <none>
probe-7db6ffd7d6-wjxpv   1/1     Running   0          32s   10.244.0.8   controlplane   <none>           <none>
shuttle                  1/1     Running   0          58s   10.244.0.6   controlplane   <none>           <none>
```

`containerd` has a new process ID and a later start time, so the new binary runs. `shuttle` kept running with zero restarts: each container runs under its own `containerd-shim` process, so a runtime restart does not stop running containers. That does not make the drain optional. A runtime that fails to start again leaves every Pod on the node without a working runtime, and a reboot after a kernel patch stops every container. As soon as the node was uncordoned, the scheduler placed the two `Pending` Pods on it.

You can now patch a node without surprises: read its versions, simulate the upgrade, drain it, restart the runtime or reboot, and return it to service. A window can still leave a cordon, a taint or a stuck Pod behind, and the open question is how to find these leftovers every time.

## Common pitfalls

> [!WARNING]
> - **Patching the kernel and not rebooting.** The package is new, but the running kernel is still the old one.
> - **Rebooting a node that was not drained.** Every Pod on it stops at once.
> - **Patching all nodes in one window step.** The application loses all capacity at the same time.
> - **Running `kubectl uncordon` and expecting the node to be normal.** A custom taint stays until you remove it.
> - **Adding `--force` to a drain without reading the list.** Bare Pods that `--force` deletes do not come back.
> - **Letting a system update upgrade held Kubernetes packages.** Keep the hold and upgrade them with the upgrade procedure.
