---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Clean Up The Default ServiceAccount

Every namespace has a `default` ServiceAccount, and every pod without a named account uses it. A new `default` account has no grants. The problem begins when someone fixes a "Forbidden" error by binding a Role to it, because that grant reaches every pod of the namespace that has no account of its own. This part finds such a binding in the playground, removes it, turns off token mounting on the account, and applies the same cleanup to the namespaces you own.

## Find grants on the default account

The playground has one such case. In `starfleet`, the Role `pod-access` lets its subjects read pods, and the RoleBinding `default-pod-access` gives the Role to the `default` account. First ask the API server what `default` may do. Then list the bindings of the namespace. The `-o wide` output has a column `SERVICEACCOUNTS` that shows each ServiceAccount subject as `namespace/name`.

<!-- astrona:playground:renew -->

```sh
kubectl auth can-i get pods -n starfleet --as=system:serviceaccount:starfleet:default
kubectl auth can-i --list -n starfleet --as=system:serviceaccount:starfleet:default
kubectl -n starfleet get rolebindings -o wide
```

The first command prints `yes`. The rule list shows `get`, `list` and `watch` on pods, which is more than a fresh `default` account has. The binding list shows `default-pod-access` with `starfleet/default` in the subject column. Because the `shuttle` pod still uses `default`, it can read pods, and so can any other pod of the namespace that names no account.

A namespace-level review also needs the cluster-wide bindings. A ClusterRoleBinding to a `default` account works in every namespace. List them with the same wide output and read the `SERVICEACCOUNTS` column:

```sh
kubectl get clusterrolebindings -o wide
```

Most rows are system bindings created by Kubernetes. Look for rows whose subjects are `default` accounts or the groups `system:serviceaccounts` and `system:serviceaccounts:<namespace>`, because those groups contain every ServiceAccount.

## Remove the grant and stop the mount

Deleting the binding removes the grant. The Role `pod-access` stays, and it does no harm without a binding. If a workload really needs it, bind it to a dedicated account instead. The second command turns off token mounting for new pods that use `default`. Then check what the account may do:

```sh
kubectl -n starfleet delete rolebinding default-pod-access
kubectl -n starfleet patch serviceaccount default -p '{"automountServiceAccountToken": false}'
kubectl auth can-i get pods -n starfleet --as=system:serviceaccount:starfleet:default
```

The last command now prints `no`. The patch changes only pods created after it, so the `shuttle` pod that already runs keeps its token until you recreate it. The `default` account is also never deleted for long: the ServiceAccount controller creates it again, so patching is the correct control, not deleting.

## Repeat for every namespace you own

The cleanup is a loop over the namespaces. The command below patches the `default` account in `starfleet` and `outpost`. Name the namespaces explicitly. Do not run the loop over all namespaces, because the system namespaces such as `kube-system` hold components that Kubernetes manages, and a patch there can change how those components start.

```sh
for namespace in starfleet outpost; do
  kubectl -n "$namespace" patch serviceaccount default -p '{"automountServiceAccountToken": false}'
done
kubectl get serviceaccounts -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,AUTOMOUNT:.automountServiceAccountToken
```

The table shows `false` for the two `default` accounts you patched. Accounts that never set the field show `<none>`, which means the token is mounted unless the pod says otherwise.

A new namespace starts with a new `default` account that again has no setting, so the patch must be repeated for each new namespace. A pod can also set `automountServiceAccountToken: true` itself and mount the token again. Two controls close the gap: a provisioning step that patches `default` when it creates a namespace, and an admission policy that rejects pods that set `true` or that name `default`. Patching alone depends on people.

You now know how to find a grant on `default`, remove it, and turn off mounting for the account. The module's rule holds in the cluster: each workload has its own account, each account has only the grants its workload uses, and `default` has none.

## Common pitfalls

> [!WARNING]
> - **Deleting the Role and keeping the binding.** A binding to a missing Role grants nothing now, but it grants again when someone creates a Role with that name.
> - **Looking only at RoleBindings.** A ClusterRoleBinding or a group subject can reach the `default` account too.
> - **Patching every namespace in a loop.** Include only namespaces you own; leave `kube-system` and other system namespaces alone.
> - **Believing a patch changes running pods.** Recreate the pods or roll out the Deployment.
> - **Forgetting new namespaces.** Each one gets a fresh `default` account.
