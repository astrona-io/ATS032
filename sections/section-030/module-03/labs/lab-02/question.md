---
exam_objectives:
- Restrict access to Kubernetes API
---
# Block NodePort Services With A ValidatingAdmissionPolicy

Allow about 10 minutes for the tasks.

A NodePort Service opens a port on every node of the cluster. The team wants to block NodePort Services in the namespace `outpost-032-030-03-02`, both for new Services and for changes to existing ones. A ValidatingAdmissionPolicy named `deny-nodeport` already exists, but it checks only `CREATE` requests and nothing binds it to a namespace yet.

## Connect to the lab

Use a shell on your own machine. The kubeconfig file holds the address and the credentials of this lab's cluster, and `kubectl` uses it.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-030-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-030-03-02" || exit 1
```

## Tasks

1. Change the ValidatingAdmissionPolicy `deny-nodeport` so that it also checks `UPDATE` requests for Services.
2. Create a ValidatingAdmissionPolicyBinding named `deny-nodeport-outpost`. It uses the policy `deny-nodeport` with the action `Deny`, and it selects only the namespace `outpost-032-030-03-02`.

After the change, creating a NodePort Service in `outpost-032-030-03-02` must be denied, and so must changing the existing Service `web` there to `NodePort`. ClusterIP Services in that namespace, and NodePort Services in `starfleet-032-030-03-02`, must still be allowed. Leave the Service `web` as type `ClusterIP`.
