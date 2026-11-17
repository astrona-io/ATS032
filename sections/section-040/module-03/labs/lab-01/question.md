---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Verify And Repair A Cluster After Maintenance

Allow about 10 minutes for the tasks.

A maintenance window on the worker of the `starfleet` cluster ended in a hurry, and nobody ran the final checks. The application still answers, but the cluster is not back to its normal state, and the next node cannot be drained safely.

## Connect to the lab

Use a shell on your own machine. The kubeconfig file holds the address and the credentials of this lab's cluster, and `kubectl` uses it.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-040-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-040-03-01" || exit 1
```

## Tasks

The Deployment `probe` in the namespace `starfleet-032-040-03-01` runs two replicas, and its Pods must run on two different nodes. A PodDisruptionBudget (a Kubernetes object that limits how many Pods of an application may be evicted at the same time) named `probe` selects them with the label `app=probe`.

1. Return the worker `astro-ats-032-lab-040-03-01-worker` to service: both nodes are Ready, and the worker is schedulable and has no taint with the key `maintenance`.
2. Make sure that two `probe` Pods are Running and Ready on two different nodes.
3. Change the PodDisruptionBudget so that it still selects `app=probe` and allows at least one disruption while both Pods are Ready. Every PodDisruptionBudget in the namespace that selects `app=probe` must allow it.

Do not delete the Deployment and do not change its affinity rules.
