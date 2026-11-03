---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Grant Only What The Workload Uses

Some workloads must call the Kubernetes API, for example a pod that lists other pods to find its peers. Such a workload needs a token and a grant. The risk is in the size of the grant: a broad Role turns a stolen token into broad access. This part creates an account for a client that needs to read pods, writes a Role with the smallest rule list that works, binds it to that one account, and tests the result without running the workload.

## Start from what the workload does

Write down the API calls first. The `shuttle` client in `starfleet` must read pods in its own namespace. That is two verbs, `get` and `list`, on one resource, `pods`, in one namespace. It does not need `watch`, `create`, `delete`, Secrets or any other namespace. The Role contains exactly that and nothing else.

A Role is a namespaced list of rules. Each rule names API groups, resources and verbs. Pods are in the core API group, which is written as an empty string. A rule can also list `resourceNames` to limit a verb to named objects. A RoleBinding connects a Role to subjects, here one ServiceAccount, and applies the Role only inside its own namespace. A RoleBinding can reference a ClusterRole too, and then the rules apply only in the namespace of the binding. A ClusterRoleBinding applies in every namespace, so avoid it for a workload that works in one namespace.

## Create the account, the Role and the binding

The file below holds three objects. The ServiceAccount `shuttle-reader` keeps the default mounting because this workload really calls the API. The Role has two rules: `get` and `list` on pods, and `get` on one named ConfigMap, `probe-code`. A rule with `resourceNames` works for `get`, `update` and `delete`. It does not limit `list` or `watch` unless the request uses a field selector on `metadata.name`, so do not use it to limit those verbs.

<!-- astrona:playground:renew -->

Save this as `rbac-shuttle-reader.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: shuttle-reader
  namespace: starfleet
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
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["probe-code"]
  verbs: ["get"]
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

The `roleRef` field of a binding cannot be changed after the binding exists. To point a binding at another Role, delete it and create it again. The `subjects` list must repeat the namespace of the ServiceAccount, because a binding can name accounts from other namespaces.

## Test the permissions without running the workload

The API server can answer what a subject may do. `kubectl auth can-i` sends that question, and `--as` makes the request on behalf of another subject. Your own credentials are `cluster-admin`, so you can impersonate any account. The first three commands ask about allowed and denied actions in `starfleet`. The next two use the `resource/name` form to ask about one ConfigMap. The last asks about another namespace.

```sh
kubectl auth can-i get pods -n starfleet --as=system:serviceaccount:starfleet:shuttle-reader
kubectl auth can-i delete pods -n starfleet --as=system:serviceaccount:starfleet:shuttle-reader
kubectl auth can-i get secrets -n starfleet --as=system:serviceaccount:starfleet:shuttle-reader
kubectl auth can-i get configmap/probe-code -n starfleet --as=system:serviceaccount:starfleet:shuttle-reader
kubectl auth can-i get configmap/other -n starfleet --as=system:serviceaccount:starfleet:shuttle-reader
kubectl auth can-i get pods -n outpost --as=system:serviceaccount:starfleet:shuttle-reader
```

The answers are `yes`, `no`, `no`, `yes`, `no` and `no`. A `no` makes `kubectl` exit with status 1, which is useful in a script. To see the whole rule list of the account in one namespace, run `kubectl auth can-i --list -n starfleet --as=system:serviceaccount:starfleet:shuttle-reader`. The table contains the rules from your Role plus the few rules that every authenticated identity receives.

## Run the workload with the account

The account exists and is tested. A pod uses it through the field `serviceAccountName`. Save this as `pod-shuttle-reader.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: shuttle-reader
  namespace: starfleet
spec:
  serviceAccountName: shuttle-reader
  restartPolicy: Never
  containers:
  - name: reader
    image: docker.io/library/busybox:1.37.0
    command: ["sh", "-c", "sleep 3600"]
```

Apply it:

```sh
kubectl apply -f pod-shuttle-reader.yaml
```

Then check the result. The pod mounts a token, because the account allows it, and the account has a binding:

```sh
kubectl -n starfleet wait --for=condition=Ready pod/shuttle-reader --timeout=90s
kubectl -n starfleet exec shuttle-reader -- ls /var/run/secrets/kubernetes.io/serviceaccount
kubectl -n starfleet describe rolebinding shuttle-reader
```

The `ls` command lists `ca.crt`, `namespace` and `token`. The `describe` command shows the Role and the one subject. The pod can now read pods in `starfleet` and nothing else, and a token stolen from this container carries only that power.

You can now create an identity, give it the smallest useful Role and prove the limits with permission checks. What remains is the account that every namespace already has, and the grants that may sit on it.

## Common pitfalls

> [!WARNING]
> - **Using `*` for verbs or resources to "make it work".** A wildcard grants everything now and everything added later.
> - **Binding with a ClusterRoleBinding for a one-namespace workload.** The grant then applies in every namespace.
> - **Forgetting the namespace in `subjects`.** A ServiceAccount subject needs its namespace.
> - **Relying on `resourceNames` to limit `list`.** It does not, unless the request filters by name.
> - **Testing only the allowed action.** Always test at least one denied action as well.
