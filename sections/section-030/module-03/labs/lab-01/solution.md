---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Enforce Admission Rules In A Namespace Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-030-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-030-03-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Inspect And Explain

Check that nothing enforces a rule yet. A server-side dry run runs the full admission chain without storing the object:

```sh
kubectl -n outpost-032-030-03-01 run priv --image=docker.io/library/busybox:1.37.0 --privileged --dry-run=server -o name
kubectl -n outpost-032-030-03-01 create service nodeport demo --tcp=80:80 --dry-run=server -o name
```

Both commands succeed in the starting state. Pod Security admission reads the labels of the namespace, and a ValidatingAdmissionPolicy needs a policy and a binding.

Label the namespace:

```sh
kubectl label namespace outpost-032-030-03-01 pod-security.kubernetes.io/enforce=baseline
```

Save this as `admission-outpost.yaml`:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: no-nodeport
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["services"]
  validations:
    - expression: "object.spec.type != 'NodePort'"
      message: "NodePort Services are not allowed in this namespace"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: no-nodeport-outpost
spec:
  policyName: no-nodeport
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: outpost-032-030-03-01
```

Apply the required change:

```sh
kubectl apply -f admission-outpost.yaml
```

## Verify The Result

The binding becomes active after a short time, so repeat a request that is still admitted. A rejected request returns a nonzero status, so run each request on its own.

```sh
kubectl -n outpost-032-030-03-01 run priv --image=docker.io/library/busybox:1.37.0 --privileged --dry-run=server -o name
kubectl -n outpost-032-030-03-01 create service nodeport demo --tcp=80:80 --dry-run=server -o name
kubectl -n outpost-032-030-03-01 create service clusterip demo --tcp=80:80 --dry-run=server -o name
kubectl -n starfleet-032-030-03-01 create service nodeport demo --tcp=80:80 --dry-run=server -o name
```

The first command fails because the Pod violates the `baseline` level. The second fails with the message of the policy `no-nodeport`. The third and fourth succeed, because a ClusterIP Service is allowed and the binding selects only `outpost-032-030-03-01`.


After recording the result, remove this independent lab with `astrona destroy ats-032-lab-030-03-01`.

## Common pitfalls

> [!WARNING]
> A policy without a binding enforces nothing. Use the namespace name label in the selector, and match both `CREATE` and `UPDATE`. Test one allowed and one denied object, and remember that `cluster-admin` is checked too.