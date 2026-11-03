---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Verify And Repair A Cluster After Maintenance Solution

Use a host shell with the private kubeconfig for this independent kind environment.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-040-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-040-03-01" || exit 1
```

## Find what is wrong

Check the nodes, the application Pods and the budget, in that order.

```sh
kubectl get nodes
kubectl -n starfleet get pods -l app=probe -o wide
kubectl -n starfleet get pdb probe
kubectl describe node astro-ats-032-lab-040-03-01-worker2 | grep -i -A2 taints
```

The second worker shows `SchedulingDisabled`. One `probe` Pod is `Pending`, because the Deployment forbids two replicas on one node and the second worker cannot take new Pods. The budget shows `ALLOWED DISRUPTIONS` of `0`. The node description lists the taint `maintenance=patching:NoSchedule`. Uncordoning removes only the unschedulable flag; the taint stays until you remove it.

## Repair the node

```sh
kubectl uncordon astro-ats-032-lab-040-03-01-worker2
kubectl taint nodes astro-ats-032-lab-040-03-01-worker2 maintenance=patching:NoSchedule-
kubectl -n starfleet rollout status deployment/probe --timeout=180s
```

## Repair the budget

Save this as `poddisruptionbudget-probe.yaml`. It replaces `minAvailable` with `maxUnavailable`:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: probe
  namespace: starfleet
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app: probe
```

Apply it and read the result:

```sh
kubectl apply -f poddisruptionbudget-probe.yaml
kubectl -n starfleet get pdb probe
```

If the apply is refused because both fields are set, delete the budget with `kubectl -n starfleet delete pdb probe` and apply the file again.

## Record the verified state

Save this as `configmap-post-maintenance-record.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: post-maintenance-record
  namespace: starfleet
data:
  nodes-ready: "3"
  probe-ready: "2"
  result: verified
```

Apply it:

```sh
kubectl apply -f configmap-post-maintenance-record.yaml
```

## Verify the result

```sh
kubectl get nodes
kubectl -n starfleet get pods -l app=probe -o wide
kubectl -n starfleet exec shuttle -- wget -q -T 3 -O- http://probe/
```

After recording your result, remove the independent lab with `astrona destroy ats-032-lab-040-03-01`.

## Common pitfalls

> [!WARNING]
> - **Running only `kubectl uncordon`.** A taint added during the window stays on the node and still blocks new Pods.
> - **Deleting the Pending Pod.** The Deployment creates a new one that stays Pending for the same reason.
> - **Recording the result before the rollout finishes.** The record would be false.
> - **Keeping `minAvailable: 2` on two replicas.** It allows no voluntary eviction, so the next drain waits until its timeout.
