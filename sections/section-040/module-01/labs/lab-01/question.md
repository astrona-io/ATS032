---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Drain And Return A Worker To Service

Solve this question on: `terminal`

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

Allow 8–10 minutes for task work. Cluster startup with two workers adds time.

## Tasks

1. Create the PodDisruptionBudget `probe` in `starfleet-032-040-01-01` with `minAvailable: 1`.
2. Cordon and drain the first worker with `--ignore-daemonsets` and a bounded timeout, then uncordon it.
3. Record the ConfigMap `maintenance-record` in `starfleet-032-040-01-01` that names that worker and has the result `returned-to-service`.

## Constraints

- Keep both `probe` replicas available and the clients running on the second worker.
- This maintenance exercise does not perform a Kubernetes binary upgrade.

## How the answer is checked

The grader runs two checks. The first checks the PodDisruptionBudget `probe`. The second checks the ConfigMap `maintenance-record` and that it names the first worker. Both checks also confirm that the first worker is schedulable and Ready, that the Deployment `probe` has two ready replicas and that `shuttle` still reaches `http://probe/`. The final grader cannot prove every earlier eviction.
