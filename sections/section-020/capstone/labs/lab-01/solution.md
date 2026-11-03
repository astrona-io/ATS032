---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Harden ServiceAccounts Across Two Namespaces Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-020-capstone-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-020-capstone-01" || exit 1
```

Keep this connection selected. Every script supplied by the lab refuses a different context.

## Inspect

Start with an audit of the two namespaces: which account each pod uses, which bindings name a ServiceAccount or a ServiceAccount group, and which long-lived token Secrets exist.

```sh
kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,SERVICEACCOUNT:.spec.serviceAccountName,AUTOMOUNT:.spec.automountServiceAccountToken
kubectl -n starfleet get rolebindings -o wide
kubectl get clusterrolebinding outpost-view-all -o wide
kubectl get secrets -A --field-selector type=kubernetes.io/service-account-token
```

The pod list shows that no pod sets the automount field and that all pods use `default`. The binding `default-pod-access` names the `default` account of `starfleet`. The group binding `outpost-view-all` names `system:serviceaccounts:outpost`. The Secret list includes `drifter-legacy-token`.

## Move `probe` to a dedicated account

Save this as `serviceaccount-probe.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: probe
  namespace: starfleet
automountServiceAccountToken: false
```

Apply it:

```sh
kubectl apply -f serviceaccount-probe.yaml
```

Point the Deployment at the account and wait for the rollout:

```sh
kubectl -n starfleet set serviceaccount deployment/probe probe
kubectl -n starfleet rollout status deployment/probe --timeout=180s
```

## Clean up the default account

Delete the binding that names `default` and turn off mounting on the account:

```sh
kubectl -n starfleet delete rolebinding default-pod-access
kubectl -n starfleet patch serviceaccount default -p '{"automountServiceAccountToken": false}'
```

## Create the narrow identity for `shuttle`

Save this as `rbac-shuttle-reader.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: shuttle-reader
  namespace: starfleet
automountServiceAccountToken: false
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: shuttle-reader
  namespace: starfleet
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: shuttle-reader
  namespace: starfleet
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: shuttle-reader
subjects:
- kind: ServiceAccount
  name: shuttle-reader
  namespace: starfleet
```

Apply it:

```sh
kubectl apply -f rbac-shuttle-reader.yaml
```

A pod cannot change its ServiceAccount after it is created, so delete `shuttle` first:

```sh
kubectl -n starfleet delete pod shuttle
```

Save this as `pod-shuttle.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: shuttle
  namespace: starfleet
  labels:
    app: shuttle
spec:
  serviceAccountName: shuttle-reader
  automountServiceAccountToken: false
  restartPolicy: Never
  containers:
  - name: client
    image: docker.io/library/busybox:1.37.0
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: api-token
      mountPath: /var/run/tokens
      readOnly: true
  volumes:
  - name: api-token
    projected:
      sources:
      - serviceAccountToken:
          path: token
          expirationSeconds: 900
```

Apply it:

```sh
kubectl apply -f pod-shuttle.yaml
```

## Remove the findings in `outpost`

Delete the token Secret and the group binding, then delete `drifter` so it can start again without a token:

```sh
kubectl -n outpost delete secret drifter-legacy-token
kubectl delete clusterrolebinding outpost-view-all
kubectl -n outpost delete pod drifter
```

Save this as `pod-drifter.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: drifter
  namespace: outpost
  labels:
    app: drifter
spec:
  automountServiceAccountToken: false
  restartPolicy: Never
  containers:
  - name: client
    image: docker.io/library/busybox:1.37.0
    command: ["sh", "-c", "sleep 3600"]
```

Apply it:

```sh
kubectl apply -f pod-drifter.yaml
```

## Verify The Result

Check the token files in the containers, then ask the API server what each account may do. Commands that print `no` or report `NotFound` exit with status 1 on purpose.

```sh
kubectl -n starfleet wait --for=condition=Ready pod/shuttle --timeout=180s
kubectl -n outpost wait --for=condition=Ready pod/drifter --timeout=180s
kubectl -n outpost exec drifter -- ls /var/run/secrets/kubernetes.io/serviceaccount
kubectl -n starfleet exec shuttle -- ls /var/run/tokens
kubectl auth can-i get pods -n starfleet --as=system:serviceaccount:starfleet:shuttle-reader
kubectl auth can-i delete pods -n starfleet --as=system:serviceaccount:starfleet:shuttle-reader
kubectl auth can-i get pods -n starfleet --as=system:serviceaccount:starfleet:default
kubectl auth can-i list pods -n starfleet --as=system:serviceaccount:outpost:default
```

The `ls` in `drifter` fails because the directory does not exist. The `ls` in `shuttle` lists `token`. The first `can-i` prints `yes` and the other three print `no`.

After recording your result, remove the independent lab with `astrona destroy ats-032-lab-020-capstone-01`.

## Common pitfalls

> [!WARNING]
> - The group binding `outpost-view-all` is a ClusterRoleBinding. Deleting a RoleBinding with a similar name does not remove it.
> - A pod cannot change its ServiceAccount, its automount field or its volumes after creation. Delete and create it again.
> - Do not bind `shuttle-reader` with a ClusterRoleBinding, and do not add `delete` or `secrets` to the Role.
> - A projected token lifetime below 600 seconds is rejected. Use 900.
