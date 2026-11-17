---
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Build An Aggregated ClusterRole: Solution

Connect to the lab cluster first. Every command below uses this connection.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-010-03-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-010-03-03" || exit 1
```

## Confirm the starting state

The ServiceAccount `probe` has no grant yet. Its user name is `system:serviceaccount:starfleet-032-010-03-03:probe`:

```sh
kubectl auth can-i list services -n dock-032-010-03-03 --as=system:serviceaccount:starfleet-032-010-03-03:probe
```

```text
no
```

## Create the ClusterRoles

A ClusterRole with an `aggregationRule` has no rules of its own. The ClusterRole aggregation controller, which runs in kube-controller-manager, watches every ClusterRole. It copies the rules of each ClusterRole that matches the `clusterRoleSelectors` into the aggregated role. The built-in `view`, `edit` and `admin` roles work the same way.

The file below holds the two labelled ClusterRoles and the aggregated one. Save this as `clusterroles-fleet-reader.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fleet-reader-pods
  labels:
    fleet.example.com/aggregate-to-fleet-reader: "true"
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fleet-reader-services
  labels:
    fleet.example.com/aggregate-to-fleet-reader: "true"
rules:
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fleet-reader
aggregationRule:
  clusterRoleSelectors:
    - matchLabels:
        fleet.example.com/aggregate-to-fleet-reader: "true"
```

Apply it:

```sh
kubectl apply -f clusterroles-fleet-reader.yaml
```

```text
clusterrole.rbac.authorization.k8s.io/fleet-reader-pods created
clusterrole.rbac.authorization.k8s.io/fleet-reader-services created
clusterrole.rbac.authorization.k8s.io/fleet-reader created
```

Then check the result. The file gave `fleet-reader` no `rules`, so any rules it has now come from the controller. The output below is shortened: the `metadata` lines are left out.

```sh
kubectl get clusterrole fleet-reader -o yaml
```

```text
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      fleet.example.com/aggregate-to-fleet-reader: "true"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
rules:
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - services
  verbs:
  - get
  - list
  - watch
```

The two rules match the two labelled ClusterRoles. A label selector shows which roles feed the aggregated role:

```sh
kubectl get clusterroles -l fleet.example.com/aggregate-to-fleet-reader=true
```

```text
NAME                    CREATED AT
fleet-reader-pods       2026-11-17T21:38:58Z
fleet-reader-services   2026-11-17T21:38:58Z
```

## Bind the role in one namespace

A RoleBinding can reference a ClusterRole. The rules then apply only in the namespace of the RoleBinding. That keeps `probe` out of every other namespace.

Save this as `rolebinding-probe-fleet-reader.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: probe-fleet-reader
  namespace: dock-032-010-03-03
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: fleet-reader
subjects:
  - kind: ServiceAccount
    name: probe
    namespace: starfleet-032-010-03-03
```

Apply it:

```sh
kubectl apply -f rolebinding-probe-fleet-reader.yaml
```

```text
rolebinding.rbac.authorization.k8s.io/probe-fleet-reader created
```

Then check the result. Test the two reads, one action that `probe` must not have, and the same read in another namespace:

```sh
kubectl auth can-i list pods -n dock-032-010-03-03 --as=system:serviceaccount:starfleet-032-010-03-03:probe
kubectl auth can-i list services -n dock-032-010-03-03 --as=system:serviceaccount:starfleet-032-010-03-03:probe
kubectl auth can-i get secrets -n dock-032-010-03-03 --as=system:serviceaccount:starfleet-032-010-03-03:probe
kubectl auth can-i list pods -n starfleet-032-010-03-03 --as=system:serviceaccount:starfleet-032-010-03-03:probe
```

```text
yes
yes
no
no
```

A real read as `probe` also works:

```sh
kubectl get services -n dock-032-010-03-03 --as=system:serviceaccount:starfleet-032-010-03-03:probe
```

```text
NAME           TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
probe-status   ClusterIP   10.96.241.216   <none>        80/TCP    25s
```

`probe` reads Pods and Services in `dock-032-010-03-03` and nothing else. A new ClusterRole with the same label would add its rules to `fleet-reader`, and `probe` would get them without any change to the binding.

## Common pitfalls

> [!WARNING]
> The label value must be the string `"true"` in quotes. Without quotes YAML reads a boolean, and a label value must be a string, so the apply fails. Do not write `rules` into the aggregated role by hand: the controller overwrites them with the union of the selected roles. If a labelled role's rules do not appear, check the label with `kubectl get clusterroles -l <key>=true`.
