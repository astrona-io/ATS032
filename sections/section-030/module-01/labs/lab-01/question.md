---
exam_objectives:
- Restrict access to Kubernetes API
---
# Give A Workload A Narrow ServiceAccount

Allow about 10 minutes for the tasks.

The `probe` Deployment in `starfleet-032-030-01-01` must read the list of Pods in its own namespace through the Kubernetes API. Today it runs as the namespace's `default` ServiceAccount, which has no access. Give it its own identity with the smallest set of rights that does the job.

## Connect to the lab

Use a shell on your own machine. The kubeconfig file holds the address and the credentials of this lab's cluster, and `kubectl` uses it.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-030-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-030-01-01" || exit 1
```

## Tasks

Work in the namespace `starfleet-032-030-01-01`.

1. Create the ServiceAccount `observer`.
2. Create the Role `observer-reader`. It allows only the verbs `get` and `list` on core `pods`, and nothing else.
3. Create the RoleBinding `observer-read`. It binds the Role `observer-reader` to the ServiceAccount `observer`. Do not bind `observer` to any other Role or ClusterRole.
4. Run the `probe` Deployment as `observer`. Wait until both replicas are ready again.

A request from a `probe` Pod, sent with the Pod's own mounted token and certificate authority, must read the Pod list of `starfleet-032-030-01-01`. The same token must get `403 Forbidden` for the Secrets of that namespace and for the Services of `outpost-032-030-01-01`.
