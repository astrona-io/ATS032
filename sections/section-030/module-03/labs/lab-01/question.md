---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Enforce Admission Rules In A Namespace

The `outpost` team shares a cluster with other teams and wants guard rails on what it can create.

## Objective

Make the API server reject privileged Pods and NodePort Services in one namespace and still admit ordinary objects.

## Starting state

The `outpost` namespace must stop accepting Pods that ask for host-level power and Services that open a port on every node. The namespaces `outpost` and `starfleet` have no admission rule. The Pod `drifter` and the Deployment `probe` are healthy. Do not change any workload.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-030-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-030-03-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Required result

Label the namespace `outpost` with `pod-security.kubernetes.io/enforce=baseline`. Create a ValidatingAdmissionPolicy named `no-nodeport` that matches `CREATE` and `UPDATE` of Services in the core API group and rejects a Service of type `NodePort`. Create a ValidatingAdmissionPolicyBinding named `no-nodeport-outpost` with the policy name `no-nodeport`, the validation action `Deny` and a namespace selector that selects only `outpost`. A privileged Pod and a NodePort Service in `outpost` must be rejected. A ClusterIP Service and a plain Pod in `outpost` must be admitted, and a NodePort Service in `starfleet` must still be admitted.

## Verify The Result

The grader checks the stated resource fields and live evidence. Wait for controller convergence before submitting. Inspect actual results rather than relying on a sample transcript.
