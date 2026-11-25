---
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Rewrite A Broad Grant As Least Privilege: Solution

Connect to the lab cluster first. Every command below uses this connection.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-010-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-010-02-01" || exit 1
```

## Find every grant of scout

A ServiceAccount is the identity a Pod uses when it calls the Kubernetes API. RBAC (Role Based Access Control) bindings can name it in two forms: as a ServiceAccount subject, or as a User subject with the name `system:serviceaccount:starfleet-032-010-02-01:scout`. Search both kinds of binding for the name `scout`:

```sh
kubectl get clusterrolebindings -o wide | grep scout
kubectl get rolebindings -A -o wide | grep scout
```

The first command finds the ClusterRoleBinding `scout-edit-everywhere` with `ClusterRole/edit` and the ServiceAccount `starfleet-032-010-02-01/scout`. The second finds the RoleBinding `release-bot` in `starfleet-032-010-02-01`. It also gives `ClusterRole/edit`, but it names `scout` in the USERS column, as `system:serviceaccount:starfleet-032-010-02-01:scout`. Both grants must go.

## Add the narrow grant first

Add the new grant before you remove the old ones, so the workload never loses the access it needs. The second rule uses `resourceNames`, which limits `get`, `update` and `patch` to the one ConfigMap `scout-report`.

Save this as `role-scout-operator.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: scout-operator
  namespace: outpost-032-010-02-01
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["scout-report"]
    verbs: ["get", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: scout-operator
  namespace: outpost-032-010-02-01
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: scout-operator
subjects:
  - kind: ServiceAccount
    name: scout
    namespace: starfleet-032-010-02-01
```

Apply it:

```sh
kubectl apply -f role-scout-operator.yaml
```

```text
role.rbac.authorization.k8s.io/scout-operator created
rolebinding.rbac.authorization.k8s.io/scout-operator created
```

Then check that the two actions the workload needs are allowed:

```sh
kubectl auth can-i list pods -n outpost-032-010-02-01 --as=system:serviceaccount:starfleet-032-010-02-01:scout
kubectl auth can-i update configmaps/scout-report -n outpost-032-010-02-01 --as=system:serviceaccount:starfleet-032-010-02-01:scout
```

```text
yes
yes
```

## Remove the broad grants

Delete the ClusterRoleBinding and check what is left:

```sh
kubectl delete clusterrolebinding scout-edit-everywhere
kubectl auth can-i get secrets -n outpost-032-010-02-01 --as=system:serviceaccount:starfleet-032-010-02-01:scout
kubectl auth can-i list pods -n starfleet-032-010-02-01 --as=system:serviceaccount:starfleet-032-010-02-01:scout
```

```text
clusterrolebinding.rbac.authorization.k8s.io "scout-edit-everywhere" deleted
no
yes
```

Secrets in `outpost-032-010-02-01` are now denied, but `scout` still lists Pods in its own namespace. The RoleBinding `release-bot` still gives it `edit` there. Delete it too:

```sh
kubectl delete rolebinding release-bot -n starfleet-032-010-02-01
kubectl auth can-i list pods -n starfleet-032-010-02-01 --as=system:serviceaccount:starfleet-032-010-02-01:scout
```

```text
rolebinding.rbac.authorization.k8s.io "release-bot" deleted from starfleet-032-010-02-01 namespace
no
```

## Check the final access

Check the allowed actions once more, then the actions that must be denied: another ConfigMap, creating ConfigMaps, deleting Pods and listing nodes.

```sh
kubectl auth can-i list pods -n outpost-032-010-02-01 --as=system:serviceaccount:starfleet-032-010-02-01:scout
kubectl auth can-i update configmaps/scout-report -n outpost-032-010-02-01 --as=system:serviceaccount:starfleet-032-010-02-01:scout
kubectl auth can-i update configmaps/other -n outpost-032-010-02-01 --as=system:serviceaccount:starfleet-032-010-02-01:scout
kubectl auth can-i create configmaps -n outpost-032-010-02-01 --as=system:serviceaccount:starfleet-032-010-02-01:scout
kubectl auth can-i delete pods -n outpost-032-010-02-01 --as=system:serviceaccount:starfleet-032-010-02-01:scout
kubectl auth can-i list nodes --as=system:serviceaccount:starfleet-032-010-02-01:scout
```

```text
yes
yes
no
no
no
Warning: resource 'nodes' is not namespace scoped

no
```

Last, confirm that the other identities kept their access. The `--as-group` flag adds a group to the request, so `jane` here stands for any member of `starfleet-crew`:

```sh
kubectl auth can-i list configmaps -n outpost-032-010-02-01 --as=system:serviceaccount:starfleet-032-010-02-01:shuttle
kubectl auth can-i list services -n outpost-032-010-02-01 --as=jane --as-group=starfleet-crew
```

```text
yes
yes
```

`scout` now holds only what its job needs, and the grants of `shuttle` and `starfleet-crew` are unchanged.

## Common pitfalls

> [!WARNING]
> `resourceNames` cannot limit `create`, because a create request has no object name yet, so leave `create` out of the ConfigMap rule. When you search for the bindings of a ServiceAccount, check the USERS column too: a binding can name it as `system:serviceaccount:<namespace>:<name>`.
