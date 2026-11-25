---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Drain A Worker Node With A PodDisruptionBudget: Solution

Connect to the lab first, so that `kubectl` talks to this lab's cluster:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-040-01-01)"
worker_name="astro-ats-032-lab-040-01-01-worker"
```

## See what blocks the drain

A drain cordons the node and then evicts its Pods. An eviction is a request to the API server to delete a Pod while it respects every PodDisruptionBudget (PDB). Start with the budget and the Pods on the worker:

```sh
kubectl -n starfleet-032-040-01-01 get pdb probe
kubectl get pods -A -o wide --field-selector spec.nodeName="$worker_name"
```

A run of this lab printed this. The Pod list is shortened to the names and namespaces:

```text
NAME    MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
probe   2               N/A               0                     6s
```

```text
kube-system               kindnet-8dbv5
kube-system               kube-proxy-6kqzb
outpost-032-040-01-01     drifter
starfleet-032-040-01-01   probe-6784f7b9b5-k2djd
starfleet-032-040-01-01   probe-6784f7b9b5-znnnm
```

The budget asks for two available Pods, and the Deployment has two. `ALLOWED DISRUPTIONS` is `0`, so the API server refuses every eviction. Try the drain once with a short timeout to see the second problem:

```sh
kubectl drain "$worker_name" --ignore-daemonsets --timeout=20s
```

The drain stops at `drifter`, because it has no controller. The first lines of the output:

```text
node/astro-ats-032-lab-040-01-01-worker cordoned
error: unable to drain node "astro-ats-032-lab-040-01-01-worker" due to error: cannot delete Pods that declare no controller (use --force to override): outpost-032-040-01-01/drifter, continuing command...
```

`--force` would delete `drifter` for good, so the task asks you to move it instead. The drain above cordoned the worker before it stopped. That is fine, because the worker must end cordoned.

## Allow one disruption

Save this as `poddisruptionbudget-probe.yaml`:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: probe
  namespace: starfleet-032-040-01-01
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: probe
```

Apply it:

```sh
kubectl apply -f poddisruptionbudget-probe.yaml
```

Then check the result:

```sh
kubectl -n starfleet-032-040-01-01 get pdb probe
```

```text
NAME    MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
probe   1               N/A               1                     22s
```

`maxUnavailable: 1` in place of `minAvailable: 1` also passes. Both let the API server evict one `probe` Pod at a time.

## Move the bare Pod

Most fields of a running Pod cannot change, so delete `drifter` and create it again on the control plane node. The control plane node has the taint `node-role.kubernetes.io/control-plane:NoSchedule`, so the new Pod needs a toleration for it. The `nodeSelector` pins the Pod to that node.

Save this as `pod-drifter.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: drifter
  namespace: outpost-032-040-01-01
  labels:
    app: drifter
spec:
  nodeSelector:
    kubernetes.io/hostname: astro-ats-032-lab-040-01-01-control-plane
  tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
  containers:
  - name: client
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 86400
```

Delete the old Pod and apply the new one:

```sh
kubectl -n outpost-032-040-01-01 delete pod drifter
kubectl apply -f pod-drifter.yaml
```

Then check the result:

```sh
kubectl -n outpost-032-040-01-01 wait --for=condition=Ready pod/drifter --timeout=60s
kubectl -n outpost-032-040-01-01 get pod drifter -o wide
```

The `NODE` column shows `astro-ats-032-lab-040-01-01-control-plane`.

## Drain the worker

Now only `probe` Pods and DaemonSet Pods remain on the worker. `--ignore-daemonsets` lets the drain skip the DaemonSet Pods, because their controller would put them back on the node anyway:

```sh
kubectl drain "$worker_name" --ignore-daemonsets --timeout=120s
```

```text
node/astro-ats-032-lab-040-01-01-worker already cordoned
Warning: ignoring DaemonSet-managed Pods: kube-system/kindnet-8dbv5, kube-system/kube-proxy-6kqzb
evicting pod starfleet-032-040-01-01/probe-6784f7b9b5-k2djd
evicting pod starfleet-032-040-01-01/probe-6784f7b9b5-znnnm
error when evicting pods/"probe-6784f7b9b5-k2djd" -n "starfleet-032-040-01-01" (will retry after 5s): Cannot evict pod as it would violate the pod's disruption budget.
evicting pod starfleet-032-040-01-01/probe-6784f7b9b5-k2djd
pod/probe-6784f7b9b5-znnnm evicted
pod/probe-6784f7b9b5-k2djd evicted
node/astro-ats-032-lab-040-01-01-worker drained
```

The error line is the budget at work. The API server evicted one Pod and refused the second until the Deployment controller had a new Pod ready on the control plane node. Then `kubectl drain` retried and the second eviction passed.

Check the Pods and the nodes:

```sh
kubectl -n starfleet-032-040-01-01 get pods -l app=probe -o wide
kubectl get nodes
```

Both `probe` Pods run on the control plane node, and the worker shows `Ready,SchedulingDisabled`. Do not run `kubectl uncordon` yet: the worker stays cordoned until its upgrade is done.
