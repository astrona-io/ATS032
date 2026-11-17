---
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Grant Namespace Pod Read Access: Solution

Connect to the lab cluster first. Every command below uses this connection.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-010-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-010-01-01" || exit 1
```

## Check the starting state

Role Based Access Control (RBAC) is the part of the API server that decides which identity may do which action on which resource. A Role lists allowed actions inside one namespace. A RoleBinding gives the actions of one Role to one or more subjects (users, groups or ServiceAccounts) in that namespace.

Start by asking the API server what `shuttle` may do now. The `--as` flag makes `kubectl` send the request as another identity. A ServiceAccount has the user name `system:serviceaccount:<namespace>:<name>`.

```sh
kubectl auth can-i list pods -n starfleet-032-010-01-01 --as=system:serviceaccount:starfleet-032-010-01-01:shuttle
```

```text
no
```

The answer is `no`, so no binding gives `shuttle` Pod access yet.

## Create the Role and the RoleBinding

The Role allows three read verbs on Pods. Pods live in the core API group, which has the empty name `""`. The RoleBinding then links the Role to the ServiceAccount.

Save this as `role-pod-reader.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: starfleet-032-010-01-01
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: shuttle-pod-reader
  namespace: starfleet-032-010-01-01
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reader
subjects:
  - kind: ServiceAccount
    name: shuttle
    namespace: starfleet-032-010-01-01
```

Apply it:

```sh
kubectl apply -f role-pod-reader.yaml
```

```text
role.rbac.authorization.k8s.io/pod-reader created
rolebinding.rbac.authorization.k8s.io/shuttle-pod-reader created
```

The same result also works with `kubectl create role pod-reader --verb=get,list,watch --resource=pods` and `kubectl create rolebinding shuttle-pod-reader --role=pod-reader --serviceaccount=starfleet-032-010-01-01:shuttle`, both with `-n starfleet-032-010-01-01`.

## Check the allowed and the denied actions

A grant is only correct when the allowed actions work and everything else stays denied. Ask the API server about each read verb first:

```sh
kubectl auth can-i get pods -n starfleet-032-010-01-01 --as=system:serviceaccount:starfleet-032-010-01-01:shuttle
kubectl auth can-i list pods -n starfleet-032-010-01-01 --as=system:serviceaccount:starfleet-032-010-01-01:shuttle
kubectl auth can-i watch pods -n starfleet-032-010-01-01 --as=system:serviceaccount:starfleet-032-010-01-01:shuttle
```

```text
yes
yes
yes
```

Then check the actions that must stay denied. `kubectl auth can-i` exits with a non-zero status for `no`, which is expected here.

```sh
kubectl auth can-i create pods -n starfleet-032-010-01-01 --as=system:serviceaccount:starfleet-032-010-01-01:shuttle
kubectl auth can-i delete pods -n starfleet-032-010-01-01 --as=system:serviceaccount:starfleet-032-010-01-01:shuttle
kubectl auth can-i get secrets -n starfleet-032-010-01-01 --as=system:serviceaccount:starfleet-032-010-01-01:shuttle
kubectl auth can-i list pods -n outpost-032-010-01-01 --as=system:serviceaccount:starfleet-032-010-01-01:shuttle
kubectl auth can-i list nodes --as=system:serviceaccount:starfleet-032-010-01-01:shuttle
```

```text
no
no
no
no
Warning: resource 'nodes' is not namespace scoped

no
```

The warning only says that nodes belong to no namespace. The Role works only inside `starfleet-032-010-01-01`, so Pods in `outpost-032-010-01-01` and nodes stay denied.

Last, list every binding that names `shuttle`. The RBAC grants of an identity add up, so one extra binding anywhere in the cluster would widen the access.

```sh
kubectl get rolebindings -A -o wide | grep shuttle
kubectl get clusterrolebindings -o wide | grep shuttle
```

The first command prints one line for `shuttle-pod-reader` in `starfleet-032-010-01-01` with `Role/pod-reader` and the ServiceAccount `starfleet-032-010-01-01/shuttle` (the line is wide, so it is not copied here). The second command prints nothing. You now have exactly one grant: Pod reads in one namespace.

## Common pitfalls

> [!WARNING]
> A ServiceAccount subject needs its `namespace` field. Without it, the binding names a ServiceAccount the API server cannot match. Also check every binding in the cluster, not only the one you created: a ClusterRoleBinding or a group binding from earlier work can still give `shuttle` more than Pod reads.
