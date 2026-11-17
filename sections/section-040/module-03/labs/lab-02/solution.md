---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Restart The Container Runtime On A Drained Worker: Solution

Connect to the lab first, so that `kubectl` talks to this lab's cluster:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-040-03-02)"
worker_name="astro-ats-032-lab-040-03-02-worker"
```

The output below comes from one run of this lab. Pod names, IP addresses and times differ in your run.

## Look at the starting state

Both `probe` Pods run on the worker:

```sh
kubectl -n starfleet-032-040-03-02 get pods -o wide
```

```text
NAME                     READY   STATUS    RESTARTS   AGE   IP           NODE                                 NOMINATED NODE   READINESS GATES
probe-6784f7b9b5-j69f2   1/1     Running   0          2s    10.244.1.2   astro-ats-032-lab-040-03-02-worker   <none>           <none>
probe-6784f7b9b5-jq5ff   1/1     Running   0          2s    10.244.1.3   astro-ats-032-lab-040-03-02-worker   <none>           <none>
```

`systemd` records when the `containerd` service last started. Read it now, so that you can compare it after the restart:

```sh
podman exec "$worker_name" systemctl show containerd --property=MainPID --property=ActiveEnterTimestamp
```

```text
MainPID=123
ActiveEnterTimestamp=Tue 2026-11-17 21:41:30 UTC
```

## Drain the worker

A runtime patch can stop or disturb the containers on the node. Drain the worker first, so that the eviction API moves the Pods while the PodDisruptionBudget still protects them:

```sh
kubectl drain "$worker_name" --ignore-daemonsets --timeout=180s
```

```text
node/astro-ats-032-lab-040-03-02-worker already cordoned
Warning: ignoring DaemonSet-managed Pods: kube-system/kindnet-rrpkq, kube-system/kube-proxy-x9hzc
evicting pod starfleet-032-040-03-02/probe-6784f7b9b5-jq5ff
evicting pod starfleet-032-040-03-02/probe-6784f7b9b5-j69f2
error when evicting pods/"probe-6784f7b9b5-jq5ff" -n "starfleet-032-040-03-02" (will retry after 5s): Cannot evict pod as it would violate the pod's disruption budget.
evicting pod starfleet-032-040-03-02/probe-6784f7b9b5-jq5ff
pod/probe-6784f7b9b5-j69f2 evicted
pod/probe-6784f7b9b5-jq5ff evicted
node/astro-ats-032-lab-040-03-02-worker drained
```

The error line is normal. The PodDisruptionBudget allows one Pod to be unavailable, so the API server refused the second eviction until the first replacement Pod was Ready. `kubectl drain` retried, and the second eviction then succeeded. The new Pods run on the control plane node, because they tolerate its taint:

```sh
kubectl -n starfleet-032-040-03-02 get pods -o wide
```

```text
NAME                     READY   STATUS    RESTARTS   AGE   IP           NODE                                        NOMINATED NODE   READINESS GATES
probe-6784f7b9b5-24wdd   1/1     Running   0          37s   10.244.0.5   astro-ats-032-lab-040-03-02-control-plane   <none>           <none>
probe-6784f7b9b5-pm6j6   1/1     Running   0          32s   10.244.0.6   astro-ats-032-lab-040-03-02-control-plane   <none>           <none>
```

## Restart containerd

`systemctl` inside the worker restarts the service. Check that it is active and that it has a new process ID and a new start time:

```sh
podman exec "$worker_name" systemctl restart containerd
podman exec "$worker_name" systemctl is-active containerd
podman exec "$worker_name" systemctl show containerd --property=MainPID --property=ActiveEnterTimestamp
```

```text
active
MainPID=1062
ActiveEnterTimestamp=Tue 2026-11-17 21:42:45 UTC
```

## Return the worker to service

The kubelet reports the node status again after the runtime is back. Wait for Ready, then uncordon the worker:

```sh
kubectl wait --for=condition=Ready node/"$worker_name" --timeout=180s
kubectl uncordon "$worker_name"
kubectl get nodes
```

```text
node/astro-ats-032-lab-040-03-02-worker condition met
node/astro-ats-032-lab-040-03-02-worker uncordoned
NAME                                        STATUS   ROLES           AGE   VERSION
astro-ats-032-lab-040-03-02-control-plane   Ready    control-plane   67s   v1.35.0
astro-ats-032-lab-040-03-02-worker          Ready    <none>          55s   v1.35.0
```

Uncordon does not move the `probe` Pods back. They stay on the control plane node until something replaces them. The grader checks that the original Pods are gone, that two `probe` Pods are available, that `containerd` started after the lab began and that the worker is Ready and schedulable.
