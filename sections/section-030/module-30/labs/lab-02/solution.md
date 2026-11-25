---
exam_objectives:
- Restrict access to Kubernetes API
---
# Block NodePort Services With A ValidatingAdmissionPolicy: Solution

Connect to the lab first, so that `kubectl` talks to this lab's cluster:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-030-03-02)"
```

## Read the existing policy

A ValidatingAdmissionPolicy holds a rule written in the Common Expression Language (CEL). The API server evaluates the rule during admission, but only for requests that a ValidatingAdmissionPolicyBinding selects. Look at the policy and the bindings:

```sh
kubectl get validatingadmissionpolicy deny-nodeport -o yaml
kubectl get validatingadmissionpolicybinding
```

The policy lists only `CREATE` under `operations`, and no binding exists. Right now the API server does not apply the policy to any request.

## Extend the policy to updates

A request that changes the type of an existing Service is an `UPDATE`. Add it to the operations. Save this as `vap-deny-nodeport.yaml`:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: deny-nodeport
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
```

Apply it:

```sh
kubectl apply -f vap-deny-nodeport.yaml
```

## Bind the policy to one namespace

The binding decides where the policy applies and what happens when the rule is false. The API server sets the label `kubernetes.io/metadata.name` on every namespace, so a selector on that label picks exactly one namespace. Save this as `vapb-deny-nodeport-outpost.yaml`:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: deny-nodeport-outpost
spec:
  policyName: deny-nodeport
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: outpost-032-030-03-02
```

Apply it:

```sh
kubectl apply -f vapb-deny-nodeport-outpost.yaml
```

## Check the result

The API server needs a few seconds to load a new binding. A server-side dry run sends a request through admission without storing it, so you can test without leaving objects behind. If the first request is still allowed, repeat it:

```sh
kubectl -n outpost-032-030-03-02 create service nodeport test --tcp=80:80 --dry-run=server
kubectl -n outpost-032-030-03-02 patch service web --dry-run=server -p '{"spec":{"type":"NodePort"}}'
kubectl -n outpost-032-030-03-02 create service clusterip test --tcp=80:80 --dry-run=server
kubectl -n starfleet-032-030-03-02 create service nodeport test --tcp=80:80 --dry-run=server
```

The first two requests are denied. The message names the policy `deny-nodeport`, the binding `deny-nodeport-outpost` and the text `NodePort Services are not allowed in this namespace`. The last two requests are allowed and print `(server dry run)`.

## Common pitfalls

> [!WARNING]
> - **Creating a policy without a binding.** The API server ignores a policy that no binding selects.
> - **Matching only `CREATE`.** A user can create a ClusterIP Service and then change it to `NodePort` with an `UPDATE`.
> - **Testing immediately.** A new binding takes a few seconds to load. Repeat the request before you change anything.
