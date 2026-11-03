---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Starting Environment

The `outpost` namespace must stop accepting Pods that ask for host-level power and Services that open a port on every node. The namespaces `outpost` and `starfleet` have no admission rule. The Pod `drifter` and the Deployment `probe` are healthy. Do not change any workload.

Label the namespace `outpost` with `pod-security.kubernetes.io/enforce=baseline`. Create a ValidatingAdmissionPolicy named `no-nodeport` that matches `CREATE` and `UPDATE` of Services in the core API group and rejects a Service of type `NodePort`. Create a ValidatingAdmissionPolicyBinding named `no-nodeport-outpost` with the policy name `no-nodeport`, the validation action `Deny` and a namespace selector that selects only `outpost`. A privileged Pod and a NodePort Service in `outpost` must be rejected. A ClusterIP Service and a plain Pod in `outpost` must be admitted, and a NodePort Service in `starfleet` must still be admitted.
