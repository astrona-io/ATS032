---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Rewrite A Broad Grant As Least Privilege Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig contains the cluster address and credentials used by kubectl, the Kubernetes command-line tool. The lab has a separate kind cluster from the module playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-010-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-010-02-01" || exit 1
```

Keep this connection selected for every command below.

## Diagnose The Starting State

The `starfleet-032-010-02-01` and `outpost-032-010-02-01` namespaces exist. The ServiceAccounts `scout` and `shuttle` live in `starfleet-032-010-02-01`. A ServiceAccount identifies a workload when it calls the Kubernetes application programming interface (API). The `scout` workload reads Pods in `outpost-032-010-02-01` and updates one ConfigMap named `scout-report` there. Today it holds the built-in `edit` ClusterRole in every namespace through the ClusterRoleBinding `scout-edit-everywhere`. Other grants exist that must keep working: `shuttle` reads ConfigMaps in `outpost-032-010-02-01`, and the group `starfleet-crew` has the `view` ClusterRole in `outpost-032-010-02-01`.

Ask the authorizer what `scout` may do today, and find the binding that gives it:

```sh
kubectl auth can-i get secrets -n outpost-032-010-02-01 --as=system:serviceaccount:starfleet-032-010-02-01:scout
kubectl get clusterrolebindings -o wide | grep scout
```

The first command prints `yes`, because the built-in `edit` ClusterRole includes Secrets in every namespace. The second command lists the ClusterRoleBinding `scout-edit-everywhere`. Role-Based Access Control (RBAC) grants add up, so the old binding must be deleted after the new grant exists.

## Add The Narrow Grant

Save this as `scout-operator.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: scout-operator
  namespace: outpost-032-010-02-01
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
kubectl apply -f scout-operator.yaml
```

## Remove The Broad Grant

Delete the ClusterRoleBinding. The Role and the RoleBinding stay in place and keep the access that `scout` needs:

```sh
kubectl delete clusterrolebinding scout-edit-everywhere
```

## Verify The Result

Observe the actual result with these bounded checks. No example transcript is provided as evidence of a completed run.

```sh
kubectl auth can-i list pods -n outpost-032-010-02-01 --as=system:serviceaccount:starfleet-032-010-02-01:scout
kubectl auth can-i update configmaps/scout-report -n outpost-032-010-02-01 --as=system:serviceaccount:starfleet-032-010-02-01:scout
kubectl auth can-i get secrets -n outpost-032-010-02-01 --as=system:serviceaccount:starfleet-032-010-02-01:scout
kubectl auth can-i list pods -n starfleet-032-010-02-01 --as=system:serviceaccount:starfleet-032-010-02-01:scout
kubectl auth can-i list configmaps -n outpost-032-010-02-01 --as=system:serviceaccount:starfleet-032-010-02-01:shuttle
```

The first two commands print `yes`. The next two print `no`. The last one prints `yes`, which shows that the grant of `shuttle` was not touched. The denied answers exit with status 1, which is expected.

After recording your result, remove this lab with `astrona destroy ats-032-lab-010-02-01`.

## Common pitfalls

> [!WARNING]
> - **Deleting the ClusterRoleBinding first.** The workload loses access until the new grant exists. Add the narrow grant, test it, then remove the broad one.
> - **Adding `create` on ConfigMaps with `resourceNames`.** A create request has no object name yet, so `resourceNames` cannot limit it. Leave `create` out.
> - **Putting the RoleBinding in `starfleet-032-010-02-01`.** The grant then applies in `starfleet-032-010-02-01`, not in `outpost-032-010-02-01`.
> - **Checking only the allowed actions.** Test the denied actions too.
