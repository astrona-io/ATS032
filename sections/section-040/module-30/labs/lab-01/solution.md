---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Verify And Repair A Cluster After Maintenance: Solution

Connect to the lab first, so that `kubectl` talks to this lab's cluster:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-040-03-01)"
worker_name="astro-ats-032-lab-040-03-01-worker"
```

The output below comes from one run of this lab. Pod names, IP addresses and ages differ in your run.

## Check the nodes

Start at the bottom layer. A node that is cordoned shows `SchedulingDisabled`, and its taints show in `kubectl describe node`:

```sh
kubectl get nodes
kubectl describe node "$worker_name" | grep -A3 Taints
```

```text
NAME                                        STATUS                     ROLES           AGE   VERSION
astro-ats-032-lab-040-03-01-control-plane   Ready                      control-plane   59s   v1.35.0
astro-ats-032-lab-040-03-01-worker          Ready,SchedulingDisabled   <none>          49s   v1.35.0
Taints:             maintenance=patching:NoSchedule
                    node.kubernetes.io/unschedulable:NoSchedule
Unschedulable:      true
Lease:
```

The worker has two problems. It is still cordoned, and it still has the taint `maintenance=patching:NoSchedule` from the maintenance window. The scheduler places no new Pod on it while either one is there.

## Check the workload

```sh
kubectl -n starfleet-032-040-03-01 get pods -o wide
kubectl -n starfleet-032-040-03-01 get pdb probe
```

```text
NAME                    READY   STATUS    RESTARTS   AGE   IP           NODE                                        NOMINATED NODE   READINESS GATES
probe-c69d5fd85-nb5xh   0/1     Pending   0          33s   <none>       <none>                                      <none>           <none>
probe-c69d5fd85-qd96v   1/1     Running   0          34s   10.244.0.5   astro-ats-032-lab-040-03-01-control-plane   <none>           <none>
NAME    MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
probe   2               N/A               0                     33s
```

One `probe` Pod is Pending. The Deployment has a required anti-affinity rule on the node name, so the second Pod cannot join the first on the control plane node. The only other node is the worker, and the worker refuses new Pods. Run `kubectl -n starfleet-032-040-03-01 describe pod <pending pod>` to read the scheduler's reason in the events.

## Return the worker to service

Remove the taint (the `-` at the end of the command removes it), then uncordon the node:

```sh
kubectl taint nodes "$worker_name" maintenance=patching:NoSchedule-
kubectl uncordon "$worker_name"
kubectl -n starfleet-032-040-03-01 rollout status deployment/probe --timeout=180s
kubectl -n starfleet-032-040-03-01 get pods -o wide
```

```text
node/astro-ats-032-lab-040-03-01-worker untainted
node/astro-ats-032-lab-040-03-01-worker uncordoned
Waiting for deployment "probe" rollout to finish: 1 of 2 updated replicas are available...
deployment "probe" successfully rolled out
NAME                    READY   STATUS    RESTARTS   AGE   IP           NODE                                        NOMINATED NODE   READINESS GATES
probe-c69d5fd85-nb5xh   1/1     Running   0          34s   10.244.1.3   astro-ats-032-lab-040-03-01-worker          <none>           <none>
probe-c69d5fd85-qd96v   1/1     Running   0          35s   10.244.0.5   astro-ats-032-lab-040-03-01-control-plane   <none>           <none>
```

The scheduler placed the Pending Pod on the worker as soon as the node accepted Pods again. Both Pods now run on different nodes.

## Fix the disruption budget

The workload is healthy, but the PodDisruptionBudget still blocks the next drain:

```sh
kubectl -n starfleet-032-040-03-01 get pdb probe
```

```text
NAME    MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
probe   2               N/A               0                     34s
```

`minAvailable: 2` with two replicas means that no Pod may ever be evicted, so `kubectl drain` would wait forever. Allow one Pod to be unavailable instead. Save this as `poddisruptionbudget-probe.yaml`:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: probe
  namespace: starfleet-032-040-03-01
spec:
  maxUnavailable: 1
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
kubectl -n starfleet-032-040-03-01 get pdb probe
kubectl get nodes
```

```text
poddisruptionbudget.policy/probe configured
NAME    MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
probe   N/A             1                 1                     34s
NAME                                        STATUS   ROLES           AGE   VERSION
astro-ats-032-lab-040-03-01-control-plane   Ready    control-plane   61s   v1.35.0
astro-ats-032-lab-040-03-01-worker          Ready    <none>          51s   v1.35.0
```

`minAvailable: 1` works as well: with two Ready Pods it also allows one disruption. The grader accepts any budget that selects `app=probe` and reports at least one allowed disruption.
