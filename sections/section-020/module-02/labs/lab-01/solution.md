---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Give Each Workload Its Own Least-Privilege ServiceAccount Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-020-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-020-02-01" || exit 1
```

Keep this connection selected. Every script supplied by the lab refuses a different context.

## Inspect

Start by listing which ServiceAccount each pod uses and which bindings name the `default` account:

```sh
kubectl -n starfleet get pods -o custom-columns=NAME:.metadata.name,SERVICEACCOUNT:.spec.serviceAccountName
kubectl -n starfleet get rolebindings -o wide
kubectl auth can-i get pods -n starfleet --as=system:serviceaccount:starfleet:default
```

Every pod of `starfleet` uses `default`. The binding `default-pod-access` names the `default` account, and the last command prints `yes`, which is the finding to remove.

## Give `probe` a dedicated account

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

Point the Deployment at the new account. Changing the pod template starts a rollout, and the command after it waits for the rollout to finish:

```sh
kubectl -n starfleet set serviceaccount deployment/probe probe
kubectl -n starfleet rollout status deployment/probe --timeout=180s
```

## Create the narrow account for the pod reader

Save this as `rbac-pod-lister.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pod-lister
  namespace: starfleet
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-lister
  namespace: starfleet
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-lister
  namespace: starfleet
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-lister
subjects:
- kind: ServiceAccount
  name: pod-lister
  namespace: starfleet
```

Apply it:

```sh
kubectl apply -f rbac-pod-lister.yaml
```

Save this as `pod-pod-lister.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-lister
  namespace: starfleet
spec:
  serviceAccountName: pod-lister
  restartPolicy: Never
  containers:
  - name: lister
    image: docker.io/library/busybox:1.37.0
    command: ["sh", "-c", "sleep 3600"]
```

Apply it:

```sh
kubectl apply -f pod-pod-lister.yaml
```

## Clean up the default account

Delete the binding that names `default`, then turn off token mounting for the account:

```sh
kubectl -n starfleet delete rolebinding default-pod-access
kubectl -n starfleet patch serviceaccount default -p '{"automountServiceAccountToken": false}'
```

## Verify The Result

Ask the API server what each account may do, and look for the token directory in a `probe` pod. A command that prints `no` exits with status 1 on purpose.

```sh
kubectl -n starfleet wait --for=condition=Ready pod/pod-lister --timeout=180s
kubectl -n starfleet exec deploy/probe -- ls /var/run/secrets/kubernetes.io/serviceaccount
kubectl auth can-i get pods -n starfleet --as=system:serviceaccount:starfleet:pod-lister
kubectl auth can-i delete pods -n starfleet --as=system:serviceaccount:starfleet:pod-lister
kubectl auth can-i get pods -n outpost --as=system:serviceaccount:starfleet:pod-lister
kubectl auth can-i get pods -n starfleet --as=system:serviceaccount:starfleet:default
```

The `ls` command fails because the directory does not exist. The first `can-i` prints `yes` and the other three print `no`. A matching field alone does not prove the behavior, so run all four.

After recording your result, remove the independent lab with `astrona destroy ats-032-lab-020-02-01`.

## Common pitfalls

> [!WARNING]
> - Set the ServiceAccount in the pod template of the Deployment, not on running pods. A pod cannot change its ServiceAccount after it is created.
> - Deleting the Role is not the fix. The binding is what gives the grant to `default`.
> - Do not bind `pod-lister` with a ClusterRoleBinding. That would give the grant in every namespace.
