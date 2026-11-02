---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Drain And Return A Worker To Service Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-040-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-040-01-01" || exit 1
node_name="astro-ats-032-lab-040-01-01-control-plane"
worker_name="astro-ats-032-lab-040-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet get pods -o wide
kubectl get nodes -o wide
```

Create PodDisruptionBudget probe with minAvailable one. Cordon and drain the first worker with --ignore-daemonsets and a bounded timeout, then uncordon it. Record ConfigMap maintenance-record naming that worker and result returned-to-service. Keep both probe replicas available and the clients running on the second worker. The final grader checks availability, the budget and schedulability; it cannot prove every earlier eviction. This maintenance exercise does not perform a Kubernetes binary upgrade.

Save this as `poddisruptionbudget-probe.yaml`:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: probe
  namespace: starfleet
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: probe
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: maintenance-record
  namespace: starfleet
data:
  node: astro-ats-032-lab-040-01-01-worker
  result: returned-to-service
```

Apply the scoped correction:

```sh
kubectl apply -f poddisruptionbudget-probe.yaml
kubectl cordon "$worker_name"
kubectl drain "$worker_name" --ignore-daemonsets --timeout=180s
kubectl uncordon "$worker_name"
kubectl apply -f poddisruptionbudget-probe.yaml
```

## Verify The Result

Observe the actual result. A denied request returns a nonzero status when the denial works, so run it separately from a shell sequence that stops on error. Status convergence and a successful request establish different parts of the result.

```sh
kubectl wait --for=condition=Ready node/"$worker_name" --timeout=180s
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n starfleet exec shuttle -- wget -q -T 3 -O- http://probe/
```

Respect disruption limits while draining and returning an isolated worker to service. The commands above deliberately target one environment. Keep its remaining components available so an unrelated failure cannot stand in for the required denial or correction. No example command output is presented as evidence of a completed run. A matching field alone does not establish that a process used it or that a controller reconciled it.

After recording your result, remove the independent lab with `astrona destroy ats-032-lab-040-01-01`.

## Common pitfalls

> [!WARNING]
> A disruption budget can block drain for a reason. Preserve bare clients on the other worker. Do not force their deletion, remove the budget or claim this is a completed version upgrade.
