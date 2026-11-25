---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Restart The Container Runtime On A Drained Node: Solution

The container runtime `containerd` starts and stops the containers of every Pod on the node. A new `containerd` package only takes effect after the service restarts, and the safe order is: drain the node, restart the service, check it, then return the node to service. Connect with `astrona ssh astro-ats-032-lab-040-03-02` and run every command below on the VM.

The output below comes from one run of this lab. Pod names, process IDs, IP addresses and times differ in your run.

## Step 1: Look at the starting state

The node is cordoned, and both `probe` Pods still run on it:

```sh
kubectl get nodes
kubectl -n starfleet-032-040-03-02 get pods -o wide
```

```text
NAME           STATUS                     ROLES           AGE   VERSION
controlplane   Ready,SchedulingDisabled   control-plane   40s   v1.35.10
NAME                     READY   STATUS    RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
probe-56fdb498b8-97s62   1/1     Running   0          25s   10.244.0.4   controlplane   <none>           <none>
probe-56fdb498b8-kwjxk   1/1     Running   0          25s   10.244.0.5   controlplane   <none>           <none>
```

`systemd`, the service manager of Ubuntu, records the process ID of the service and the time it last started. Read both now, so that you can compare them after the restart:

```sh
systemctl show containerd --property=MainPID --property=ActiveEnterTimestamp
```

```text
MainPID=799
ActiveEnterTimestamp=Wed 2026-11-18 08:53:18 UTC
```

## Step 2: Drain the node

A runtime restart can disturb the containers on the node, so the workload leaves first. `kubectl drain` cordons the node (it already is) and asks the API server to evict every Pod that a controller manages. `--ignore-daemonsets` skips the `kube-proxy` Pod, because its DaemonSet would put it straight back:

```sh
kubectl drain controlplane --ignore-daemonsets --timeout=180s
kubectl -n starfleet-032-040-03-02 get pods -o wide
```

```text
node/controlplane already cordoned
Warning: ignoring DaemonSet-managed Pods: kube-system/kube-proxy-q2d6l
evicting pod starfleet-032-040-03-02/probe-56fdb498b8-kwjxk
evicting pod kube-system/coredns-7d764666f9-sf4zn
evicting pod kube-system/coredns-7d764666f9-nflzt
evicting pod starfleet-032-040-03-02/probe-56fdb498b8-97s62
pod/coredns-7d764666f9-sf4zn evicted
pod/coredns-7d764666f9-nflzt evicted
pod/probe-56fdb498b8-kwjxk evicted
pod/probe-56fdb498b8-97s62 evicted
node/controlplane drained
NAME                     READY   STATUS    RESTARTS   AGE   IP       NODE     NOMINATED NODE   READINESS GATES
probe-56fdb498b8-mb27x   0/1     Pending   0          31s   <none>   <none>   <none>           <none>
probe-56fdb498b8-wsctd   0/1     Pending   0          31s   <none>   <none>   <none>           <none>
```

The Deployment controller created two new `probe` Pods at once. They stay `Pending`, because the scheduler has no schedulable node to place them on. In a cluster with more nodes they would start on another node. With one node, the application is down for the window, which is why production clusters patch one node of several at a time.

The drain also evicted the two CoreDNS Pods. If a PodDisruptionBudget had protected `probe` with `maxUnavailable: 1`, this drain would wait until it times out: the first replacement Pod can never become Ready on a cordoned single node, so the API server would refuse the second eviction.

## Step 3: Restart containerd

`systemctl` restarts the service. Then check that it is active and that it has a new process ID and a new start time:

```sh
sudo systemctl restart containerd
systemctl is-active containerd
systemctl show containerd --property=MainPID --property=ActiveEnterTimestamp
```

```text
active
MainPID=3344
ActiveEnterTimestamp=Wed 2026-11-18 08:54:42 UTC
```

The new process ID and the later time prove that the new binary now runs. If `is-active` prints `failed` or `activating`, read the reason with `sudo journalctl -u containerd -n 20` before you go on.

## Step 4: Return the node to service

The kubelet reports the node status again after the runtime is back. Wait for Ready, uncordon the node and wait for the Deployment:

```sh
kubectl wait --for=condition=Ready node/controlplane --timeout=180s
kubectl uncordon controlplane
kubectl -n starfleet-032-040-03-02 rollout status deployment/probe --timeout=180s
kubectl get nodes
kubectl -n starfleet-032-040-03-02 get pods -o wide
```

```text
node/controlplane condition met
node/controlplane uncordoned
Waiting for deployment "probe" rollout to finish: 0 of 2 updated replicas are available...
Waiting for deployment "probe" rollout to finish: 1 of 2 updated replicas are available...
deployment "probe" successfully rolled out
NAME           STATUS   ROLES           AGE   VERSION
controlplane   Ready    control-plane   77s   v1.35.10
NAME                     READY   STATUS    RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
probe-56fdb498b8-mb27x   1/1     Running   0          37s   10.244.0.9   controlplane   <none>           <none>
probe-56fdb498b8-wsctd   1/1     Running   0          37s   10.244.0.7   controlplane   <none>           <none>
```

As soon as the node accepted Pods again, the scheduler placed the two `Pending` Pods on it. The grader checks that the original `probe` Pods are gone, that two `probe` Pods are available, that `containerd` started again after the lab began, and that the node is Ready and schedulable.
