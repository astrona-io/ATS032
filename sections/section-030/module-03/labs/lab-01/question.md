---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Enforce Admission Rules In A Namespace

Solve this question on: `terminal`

The `outpost-032-030-03-01` team shares a cluster with other teams and wants guard rails on what it can create.

## Objective

Make the API server reject privileged Pods and NodePort Services in one namespace and still admit ordinary objects.

## Starting state

The `outpost-032-030-03-01` namespace must stop accepting Pods that ask for host-level power and Services that open a port on every node. The namespaces `outpost-032-030-03-01` and `starfleet-032-030-03-01` have no admission rule. The Pod `drifter` and the Deployment `probe` are healthy. Do not change any workload.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-030-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-030-03-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

Allow 8–10 minutes for task work. Cluster startup adds time.

## Tasks

1. Label the namespace `outpost-032-030-03-01` with `pod-security.kubernetes.io/enforce=baseline`.
2. Create a ValidatingAdmissionPolicy named `no-nodeport` that matches `CREATE` and `UPDATE` of Services in the core API group and rejects a Service of type `NodePort`.
3. Create a ValidatingAdmissionPolicyBinding named `no-nodeport-outpost` with the policy name `no-nodeport`, the validation action `Deny` and a namespace selector that selects only `outpost-032-030-03-01`.

## Constraints

- A ClusterIP Service and a plain Pod in `outpost-032-030-03-01` must still be admitted.
- A NodePort Service in `starfleet-032-030-03-01` must still be admitted.
- Do not change any workload.

## How the answer is checked

The grader runs two checks. The first checks the namespace label, then sends a privileged Pod and a plain Pod to `outpost-032-030-03-01` as server-side dry runs: the privileged Pod must be rejected and the plain Pod admitted. The second checks the policy and its binding, then sends dry-run Services: a NodePort Service in `outpost-032-030-03-01` must be rejected, and a ClusterIP Service there and a NodePort Service in `starfleet-032-030-03-01` admitted.
