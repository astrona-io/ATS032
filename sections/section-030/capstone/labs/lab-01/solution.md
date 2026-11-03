---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Restrict API Access End To End Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-030-capstone-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-030-capstone-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Inspect And Explain

Start with the facts that the three changes depend on:

```sh
kubectl -n starfleet get deployment probe -o jsonpath='{.spec.template.spec.serviceAccountName}{"\n"}'
kubectl get clusterrolebindings -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.subjects[*].name}{"\n"}{end}'
kubectl -n starfleet run priv --image=docker.io/library/busybox:1.37.0 --privileged --dry-run=server -o name
```

The first command prints nothing, because the Deployment uses the `default` account. The second shows `anonymous-viewer` with the subject `system:unauthenticated`. The third succeeds, which shows that no admission rule applies yet.

Save this as `capstone.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: lister
  namespace: starfleet
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: service-lister
  namespace: starfleet
rules:
- apiGroups:
  - ''
  resources:
  - services
  verbs:
  - get
  - list
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: service-lister-bind
  namespace: starfleet
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: service-lister
subjects:
- kind: ServiceAccount
  name: lister
  namespace: starfleet
---
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
  name: no-nodeport-starfleet
spec:
  policyName: no-nodeport
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: starfleet
```

Apply it, run the Deployment as the new account and wait for the rollout:

```sh
kubectl apply -f capstone.yaml
kubectl -n starfleet set serviceaccount deployment/probe lister
kubectl -n starfleet rollout status deployment/probe --timeout=180s
```

Remove the binding for anonymous callers and enforce the Pod Security level:

```sh
kubectl delete clusterrolebinding anonymous-viewer
kubectl label namespace starfleet pod-security.kubernetes.io/enforce=baseline
```

## Verify The Result

Wait a few seconds after the last change. Authorization and the new binding need a short time to apply, so repeat a request that still shows the old result. Run the denied commands one at a time, because a rejected request returns a nonzero status.

```sh
kubectl auth can-i list services -n starfleet --as=system:serviceaccount:starfleet:lister
kubectl auth can-i list pods -n starfleet --as=ops-user --as-group=ops
kubectl -n starfleet run priv --image=docker.io/library/busybox:1.37.0 --privileged --dry-run=server -o name
kubectl -n starfleet create service nodeport demo --tcp=80:80 --dry-run=server -o name
kubectl -n starfleet create service clusterip demo --tcp=80:80 --dry-run=server -o name
kubectl -n outpost create service nodeport demo --tcp=80:80 --dry-run=server -o name
```

The first two commands print `yes`. The privileged Pod and the NodePort Service in `starfleet` are rejected. The ClusterIP Service in `starfleet` and the NodePort Service in `outpost` are admitted. To prove the identity from the workload, send a request from a `probe` Pod with its mounted token and the certificate authority file: the Service list returns `200`, and the Pod list returns `403`. Send the same Pod list request without a token and it also returns `403`.


After recording the result, remove this independent lab with `astrona destroy ats-032-lab-030-capstone-01`.

## Common pitfalls

> [!WARNING]
> Wait for the rollout before you test the identity, because old replicas keep the old token. Delete the binding and keep `ops-viewer`. A policy needs its binding, and the selector must name only `starfleet`. A host-side check does not prove the workload identity: send a request from the Pod.