---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Restrict API Access End To End

A security review of the `starfleet` namespace found three problems at once: a shared identity, anonymous read access and no guard rails on what can be created.

## Objective

Give a workload a narrow identity, remove anonymous access to the API and add admission rules to a namespace, and prove each result with requests.

## Starting state

The `starfleet` namespace runs the `probe` Deployment (two Pods) with the `default` ServiceAccount. The API server answers anonymous requests, because the ClusterRoleBinding `anonymous-viewer` gives `view` to the group `system:unauthenticated`. The binding `ops-viewer` gives `view` to the group `ops` and is correct. No admission rule exists in `starfleet`. The Deployment `probe` can send requests to the API server.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-030-capstone-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-030-capstone-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Required result

Make these changes, using exactly these names.

1. Create the ServiceAccount `lister`, the Role `service-lister` that grants exactly `get` and `list` on core `services`, and the RoleBinding `service-lister-bind` for the ServiceAccount, all in `starfleet`. Run the `probe` Deployment as `lister` and wait for both replicas.
2. Remove the ClusterRoleBinding `anonymous-viewer` and keep `ops-viewer` unchanged.
3. Label the namespace `starfleet` with `pod-security.kubernetes.io/enforce=baseline`.
4. Create the ValidatingAdmissionPolicy `no-nodeport` (matching `CREATE` and `UPDATE` of core Services and rejecting the type `NodePort`) and the ValidatingAdmissionPolicyBinding `no-nodeport-starfleet` with the action `Deny` and a namespace selector that selects only `starfleet`.

Then the following must hold. A request from a `probe` Pod that uses its mounted token lists Services in `starfleet` with `200` and lists Pods with `403`. An anonymous request to the Pod list returns `403`, and an anonymous request to `/version` returns `200`. The group `ops` can still list Pods in `starfleet`. A privileged Pod and a NodePort Service in `starfleet` are rejected, a ClusterIP Service in `starfleet` is admitted and a NodePort Service in `outpost` is admitted.

## Verify The Result

The grader checks the stated resource fields and live evidence. Wait for controller convergence before submitting. Inspect actual results rather than relying on a sample transcript.
