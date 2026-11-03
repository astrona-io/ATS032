---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Remediate An RBAC Review Across Three Namespaces Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig contains the cluster address and credentials used by kubectl, the Kubernetes command-line tool. The lab has a separate kind cluster from the module playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-010-capstone-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-010-capstone-01" || exit 1
```

Keep this connection selected for every command below.

## Diagnose The Starting State

The namespaces `starfleet`, `outpost` and `dock` exist. The ServiceAccounts `scout` and `probe` live in `starfleet`. A ServiceAccount identifies a workload when it calls the Kubernetes application programming interface (API). A review found four problems. The ClusterRoleBinding `scout-edit-everywhere` gives `scout` the built-in `edit` ClusterRole in every namespace, but `scout` only reads Pods in `outpost` and updates the ConfigMap `scout-report` there. The ClusterRoleBinding `everyone-view` gives the built-in `view` ClusterRole to the group `system:authenticated`. The Role `crew-operator` in `outpost` uses the wildcard `*` for API groups, resources and verbs and is bound to the group `outpost-crew`. The `probe` workload needs to read Pods and Services in `dock` and has no grant yet.

List the bindings and test what each identity can do today:

```sh
kubectl get clusterrolebindings -o wide | grep -E 'scout|everyone'
kubectl -n outpost get role crew-operator -o yaml
kubectl auth can-i get secrets -n outpost --as=system:serviceaccount:starfleet:scout
kubectl auth can-i list pods -n dock --as=system:serviceaccount:starfleet:probe
```

The last two commands print `yes`. The first because `edit` includes Secrets, the second because `everyone-view` reaches every authenticated identity. Role-Based Access Control (RBAC) grants add up, so each broad grant must be deleted after a narrow replacement exists.

## Apply The Narrow Grants

Save this as `rbac-review.yaml`. It holds the Role and RoleBinding for `scout`, the replacement rules of `crew-operator`, the two labelled component ClusterRoles, the aggregated ClusterRole and the RoleBinding in `dock`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: scout-operator
  namespace: outpost
rules:
- apiGroups:
  - ''
  resources:
  - pods
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ''
  resources:
  - configmaps
  resourceNames:
  - scout-report
  verbs:
  - get
  - update
  - patch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: scout-operator
  namespace: outpost
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: scout-operator
subjects:
- kind: ServiceAccount
  name: scout
  namespace: starfleet
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: crew-operator
  namespace: outpost
rules:
- apiGroups:
  - ''
  resources:
  - pods
  - services
  - configmaps
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - apps
  resources:
  - deployments
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fleet-reader-pods
  labels:
    fleet.example.com/aggregate-to-fleet-reader: "true"
rules:
- apiGroups:
  - ''
  resources:
  - pods
  verbs:
  - get
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fleet-reader-services
  labels:
    fleet.example.com/aggregate-to-fleet-reader: "true"
rules:
- apiGroups:
  - ''
  resources:
  - services
  verbs:
  - get
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fleet-reader
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      fleet.example.com/aggregate-to-fleet-reader: "true"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: probe-fleet-reader
  namespace: dock
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: fleet-reader
subjects:
- kind: ServiceAccount
  name: probe
  namespace: starfleet
```

Apply it:

```sh
kubectl apply -f rbac-review.yaml
```

## Remove The Broad Grants

Delete the two ClusterRoleBindings after the replacements exist:

```sh
kubectl delete clusterrolebinding scout-edit-everywhere everyone-view
```

## Verify The Result

Observe the actual result with these bounded checks. No example transcript is provided as evidence of a completed run.

```sh
kubectl auth can-i update configmaps/scout-report -n outpost --as=system:serviceaccount:starfleet:scout
kubectl auth can-i get secrets -n outpost --as=system:serviceaccount:starfleet:scout
kubectl auth can-i create deployments.apps -n outpost --as=jane --as-group=outpost-crew
kubectl auth can-i get pods/log -n outpost --as=jane --as-group=outpost-crew
kubectl auth can-i get services -n dock --as=system:serviceaccount:starfleet:probe
kubectl auth can-i list pods -n outpost --as=system:serviceaccount:starfleet:probe
```

The first, third and fifth commands print `yes`. The other three print `no`. If the fifth command prints `no`, wait a few seconds: the controller fills the rules of `fleet-reader` shortly after the component roles exist. The denied answers exit with status 1, which is expected.

After recording your result, remove this lab with `astrona destroy ats-032-lab-010-capstone-01`.

## Common pitfalls

> [!WARNING]
> - **Deleting a ClusterRoleBinding before its replacement exists.** The workload loses access in between.
> - **Writing `rules` in the aggregated ClusterRole.** The controller overwrites them. Put the rules in the labelled component roles.
> - **Using a different label in a component role.** The selector matches the label exactly, so the role is not included.
> - **Binding `fleet-reader` with a ClusterRoleBinding.** The grant then reaches every namespace instead of `dock`.
> - **Forgetting that `pods/log` is a separate resource.** A rule for `pods` does not cover it.
