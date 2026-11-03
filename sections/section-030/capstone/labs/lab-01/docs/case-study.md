---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Starting Environment

The `starfleet` namespace runs the `probe` Deployment (two Pods) with the `default` ServiceAccount. The API server answers anonymous requests, because the ClusterRoleBinding `anonymous-viewer` gives `view` to the group `system:unauthenticated`. The binding `ops-viewer` gives `view` to the group `ops` and is correct. No admission rule exists in `starfleet`. The Deployment `probe` can send requests to the API server.

Make these changes, using exactly these names.

1. Create the ServiceAccount `lister`, the Role `service-lister` that grants exactly `get` and `list` on core `services`, and the RoleBinding `service-lister-bind` for the ServiceAccount, all in `starfleet`. Run the `probe` Deployment as `lister` and wait for both replicas.
2. Remove the ClusterRoleBinding `anonymous-viewer` and keep `ops-viewer` unchanged.
3. Label the namespace `starfleet` with `pod-security.kubernetes.io/enforce=baseline`.
4. Create the ValidatingAdmissionPolicy `no-nodeport` (matching `CREATE` and `UPDATE` of core Services and rejecting the type `NodePort`) and the ValidatingAdmissionPolicyBinding `no-nodeport-starfleet` with the action `Deny` and a namespace selector that selects only `starfleet`.

Then the following must hold. A request from a `probe` Pod that uses its mounted token lists Services in `starfleet` with `200` and lists Pods with `403`. An anonymous request to the Pod list returns `403`, and an anonymous request to `/version` returns `200`. The group `ops` can still list Pods in `starfleet`. A privileged Pod and a NodePort Service in `starfleet` are rejected, a ClusterIP Service in `starfleet` is admitted and a NodePort Service in `outpost` is admitted.
