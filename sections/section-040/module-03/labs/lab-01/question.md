---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Verify And Repair A Cluster After Maintenance

Solve this question on: `terminal`

A maintenance window on the second worker ended in a hurry. Nobody ran the final checks. The application still answers, but the cluster is not back to its normal state.

## Starting state

The Deployment `probe` in `starfleet-032-040-03-01` should run two replicas on two different nodes. A PodDisruptionBudget named `probe` exists. The clients `shuttle` and `drifter` run on the first worker.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-040-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-040-03-01" || exit 1
```

Keep this connection selected. Every script supplied by the lab refuses a different context.

Allow 6–8 minutes for task work. Cluster startup with two workers adds time.

## Tasks

1. Return the second worker to normal scheduling. It must be schedulable and must carry no taint with the key `maintenance`. Both `probe` replicas must then be running and ready, on two different nodes.
2. Replace the PodDisruptionBudget `probe` so that it uses `maxUnavailable: 1` and no `minAvailable`. The next drain of one node must be allowed.
3. When the cluster is healthy, create the ConfigMap `post-maintenance-record` in `starfleet-032-040-03-01` with the data `nodes-ready: "3"`, `probe-ready: "2"` and `result: verified`.

## Constraints

- Do not delete or recreate the Deployment `probe`, and do not delete the clients.
- The `shuttle` Pod must still reach `http://probe/`.

## How the answer is checked

The grader runs four checks. The first checks that the second worker is schedulable with no `maintenance` taint. The second checks that both `probe` replicas are ready on two different nodes. The third checks the PodDisruptionBudget `probe`. The fourth checks the ConfigMap `post-maintenance-record`. Every check also sends one request from `shuttle` to `http://probe/`. Wait for the Deployment to finish before you create the record.
