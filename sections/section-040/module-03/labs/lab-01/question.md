---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Verify And Repair A Cluster After Maintenance

A maintenance window on the second worker ended in a hurry. Nobody ran the final checks. The application still answers, but the cluster is not back to its normal state.

## Starting state

The Deployment `probe` in `starfleet` should run two replicas on two different nodes. A PodDisruptionBudget named `probe` exists. The clients `shuttle` and `drifter` run on the first worker.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-040-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-040-03-01" || exit 1
```

Keep this connection selected. Every script supplied by the lab refuses a different context.

## Required result

Run the post-maintenance checks, find what is wrong and repair it without deleting or recreating the Deployment.

1. Return the second worker to normal scheduling. It must be schedulable and must carry no taint with the key `maintenance`.
2. Both `probe` replicas must be running and ready, on two different nodes.
3. Replace the PodDisruptionBudget `probe` so that it uses `maxUnavailable: 1` and no `minAvailable`. The next drain of one node must be allowed.
4. When the cluster is healthy, create the ConfigMap `post-maintenance-record` in `starfleet` with the data `nodes-ready: "3"`, `probe-ready: "2"` and `result: verified`.

The `shuttle` Pod must still reach `http://probe/`. Do not change the Deployment, and do not delete the clients.

## Verify The Result

The grader reads the node, the Pods, the budget and the ConfigMap, and sends one request from `shuttle`. Wait for the Deployment to finish before you create the record.
