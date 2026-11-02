---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Drain And Return A Worker To Service

Respect disruption limits while draining and returning an isolated worker to service.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-040-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-040-01-01" || exit 1
node_name="astro-ats-032-lab-040-01-01-control-plane"
worker_name="astro-ats-032-lab-040-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Create PodDisruptionBudget probe with minAvailable one. Cordon and drain the first worker with --ignore-daemonsets and a bounded timeout, then uncordon it. Record ConfigMap maintenance-record naming that worker and result returned-to-service. Keep both probe replicas available and the clients running on the second worker. The final grader checks availability, the budget and schedulability; it cannot prove every earlier eviction. This maintenance exercise does not perform a Kubernetes binary upgrade.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
