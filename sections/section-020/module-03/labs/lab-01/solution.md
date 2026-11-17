# Remove Over-Broad ServiceAccount Bindings: Solution

A ServiceAccount gets permissions from every binding that names it, and also from every binding that names one of its groups. Kubernetes puts each ServiceAccount in the group `system:serviceaccounts` (all ServiceAccounts of the cluster) and in `system:serviceaccounts:<namespace>` (all ServiceAccounts of its namespace). A binding to a group does not contain the account name, so a search for the name alone misses it.

## Step 1: Find the bindings

First connect to the lab cluster:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-020-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-020-03-01" || exit 1
```

List the RoleBindings of the namespace, then the ClusterRoleBindings whose subjects are ServiceAccounts or ServiceAccount groups:

```sh
kubectl -n outpost-032-020-03-01 get rolebindings -o wide
kubectl get clusterrolebindings -o custom-columns=NAME:.metadata.name,ROLE:.roleRef.name,KIND:.subjects[*].kind,SUBJECT:.subjects[*].name | grep -E 'ServiceAccount|system:serviceaccounts'
```

```text
NAME               ROLE               AGE   USERS   GROUPS                                         SERVICEACCOUNTS
outpost-all-view   ClusterRole/view   5s            system:serviceaccounts:outpost-032-020-03-01   
kindnet                                                         kindnet                                                                ServiceAccount   kindnet
kubeadm:node-proxier                                            system:node-proxier                                                    ServiceAccount   kube-proxy
ledger-edit                                                     edit                                                                   ServiceAccount   ledger
local-path-provisioner-bind                                     local-path-provisioner-role                                            ServiceAccount   local-path-provisioner-service-account
outpost-view-all                                                view                                                                   Group            system:serviceaccounts:outpost-032-020-03-01
system:controller:attachdetach-controller                       system:controller:attachdetach-controller                              ServiceAccount   attachdetach-controller
...
system:service-account-issuer-discovery                         system:service-account-issuer-discovery                                Group            system:serviceaccounts
```

The output is shortened: about 40 rows of `system:` bindings are left out. Kubernetes creates those for its own controllers and for CoreDNS. Three bindings belong to the lab:

- The RoleBinding `outpost-all-view` gives `view` to every ServiceAccount of the namespace.
- The ClusterRoleBinding `ledger-edit` gives `edit` to `ledger` in every namespace of the cluster.
- The ClusterRoleBinding `outpost-view-all` gives `view` to every ServiceAccount of the namespace, in every namespace.

The last row, `system:service-account-issuer-discovery`, is a default binding. It only lets ServiceAccounts read the public keys that verify tokens, so leave it.

## Step 2: Confirm the effect with the API server

Ask the API server what the two ServiceAccounts may do, in their own namespace and in `default`:

```sh
kubectl auth can-i get secrets -n outpost-032-020-03-01 --as=system:serviceaccount:outpost-032-020-03-01:ledger
kubectl auth can-i get secrets -n default --as=system:serviceaccount:outpost-032-020-03-01:ledger
kubectl auth can-i list pods -n outpost-032-020-03-01 --as=system:serviceaccount:outpost-032-020-03-01:archive
kubectl auth can-i list pods -n default --as=system:serviceaccount:outpost-032-020-03-01:archive
```

```text
yes
yes
yes
yes
```

`ledger` can read Secrets in any namespace, which includes the credentials of other workloads. `archive` has no binding with its own name, yet it can list Pods everywhere through the group bindings.

## Step 3: Delete the over-broad bindings

`kubectl delete` accepts several names of the same kind in one command:

```sh
kubectl delete clusterrolebinding ledger-edit outpost-view-all
kubectl -n outpost-032-020-03-01 delete rolebinding outpost-all-view
```

```text
clusterrolebinding.rbac.authorization.k8s.io "ledger-edit" deleted
clusterrolebinding.rbac.authorization.k8s.io "outpost-view-all" deleted
rolebinding.rbac.authorization.k8s.io "outpost-all-view" deleted from outpost-032-020-03-01 namespace
```

Do not delete the ClusterRoles `edit` and `view`. They are built-in roles that other bindings use.

## Step 4: Give ledger only what it needs

Save this as `role-config-reader.yaml`:

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
```

Save this as `rolebinding-config-reader.yaml`:

```yaml
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

Apply them:

```sh
kubectl apply -f role-config-reader.yaml
kubectl apply -f rolebinding-config-reader.yaml
```

```text
role.rbac.authorization.k8s.io/config-reader created
rolebinding.rbac.authorization.k8s.io/config-reader created
```

## Step 5: Check the result

Ask the same kind of questions again:

```sh
kubectl auth can-i list configmaps -n outpost-032-020-03-01 --as=system:serviceaccount:outpost-032-020-03-01:ledger
kubectl auth can-i get secrets -n outpost-032-020-03-01 --as=system:serviceaccount:outpost-032-020-03-01:ledger
kubectl auth can-i list configmaps -n default --as=system:serviceaccount:outpost-032-020-03-01:ledger
kubectl auth can-i list pods -n outpost-032-020-03-01 --as=system:serviceaccount:outpost-032-020-03-01:archive
kubectl auth can-i list pods -n default --as=system:serviceaccount:outpost-032-020-03-01:archive
```

```text
yes
no
no
no
no
```

`ledger` can read ConfigMaps in its own namespace only, and `archive` can no longer read anything. For a full list of rules, run `kubectl auth can-i --list -n outpost-032-020-03-01 --as=system:serviceaccount:outpost-032-020-03-01:ledger`. Its output also shows the small default rules that every authenticated user has, such as `create` on `selfsubjectreviews`.
