---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Remove ServiceAccount Findings From A Namespace Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-020-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-020-03-01" || exit 1
```

Keep this connection selected. Every script supplied by the lab refuses a different context.

## Inspect

Start with the audit commands. They list the pods with their ServiceAccounts, the token Secrets and the bindings that name a ServiceAccount or a ServiceAccount group:

```sh
kubectl get pods -n outpost-032-020-03-01 -o custom-columns=NAME:.metadata.name,SERVICEACCOUNT:.spec.serviceAccountName,AUTOMOUNT:.spec.automountServiceAccountToken
kubectl get secrets -A --field-selector type=kubernetes.io/service-account-token
kubectl -n outpost-032-020-03-01 get rolebindings -o wide
kubectl get clusterrolebinding ledger-edit -o wide
kubectl -n outpost-032-020-03-01 get pod ledger-client -o jsonpath='{.spec.volumes[0].projected.sources[0].serviceAccountToken.expirationSeconds}{"\n"}'
```

The pod list shows that `archive-reader` leaves the pod field unset, the Secret list includes `ledger-legacy-token`, the two bindings name `ledger` and the group, and the last command prints `86400`.

## Remove the findings

Delete the token Secret and the two bindings:

```sh
kubectl -n outpost-032-020-03-01 delete secret ledger-legacy-token
kubectl delete clusterrolebinding ledger-edit
kubectl -n outpost-032-020-03-01 delete rolebinding outpost-all-view
```

## Keep the one permission the workload needs

Save this as `rbac-config-reader.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: config-reader
  namespace: outpost-032-020-03-01
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: config-reader
  namespace: outpost-032-020-03-01
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: config-reader
subjects:
- kind: ServiceAccount
  name: ledger
  namespace: outpost-032-020-03-01
```

Apply it:

```sh
kubectl apply -f rbac-config-reader.yaml
```

## Recreate the pod with a short token

A pod cannot change its volumes after it is created, so delete it first:

```sh
kubectl -n outpost-032-020-03-01 delete pod ledger-client
```

Save this as `pod-ledger-client.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ledger-client
  namespace: outpost-032-020-03-01
  labels:
    app: ledger-client
spec:
  serviceAccountName: ledger
  automountServiceAccountToken: false
  restartPolicy: Never
  containers:
  - name: client
    image: docker.io/library/busybox:1.37.0
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: ledger-token
      mountPath: /var/run/tokens
      readOnly: true
  volumes:
  - name: ledger-token
    projected:
      sources:
      - serviceAccountToken:
          path: token
          expirationSeconds: 3600
```

Apply it:

```sh
kubectl apply -f pod-ledger-client.yaml
```

## Verify The Result

Check the three removed objects, then ask the API server what the two accounts may do. Commands that print `no` or report `NotFound` exit with status 1 on purpose.

```sh
kubectl -n outpost-032-020-03-01 wait --for=condition=Ready pod/ledger-client --timeout=180s
kubectl -n outpost-032-020-03-01 get secret ledger-legacy-token
kubectl auth can-i get configmaps -n outpost-032-020-03-01 --as=system:serviceaccount:outpost-032-020-03-01:ledger
kubectl auth can-i get secrets -n outpost-032-020-03-01 --as=system:serviceaccount:outpost-032-020-03-01:ledger
kubectl auth can-i list pods -n outpost-032-020-03-01 --as=system:serviceaccount:outpost-032-020-03-01:archive
```

The Secret lookup reports that the Secret is not found. The first `can-i` prints `yes` and the last two print `no`.

After recording your result, remove the independent lab with `astrona destroy ats-032-lab-020-03-01`.

## Common pitfalls

> [!WARNING]
> - Deleting only the ClusterRoleBinding is not enough. The group binding in `outpost-032-020-03-01` also reaches every ServiceAccount of the namespace, including `archive`.
> - A token lifetime below 600 seconds is rejected. Use 3600.
> - Do not delete the ServiceAccount `ledger`. The pod needs it and the new Role binds to it.
