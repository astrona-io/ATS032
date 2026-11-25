---
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Revoke An Action That Several Bindings Grant: Solution

Connect to the lab cluster first. Every command below uses this connection.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-010-01-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-010-01-03" || exit 1
```

## Find every binding that reaches shuttle

RBAC (Role Based Access Control) rules only add permissions. There is no deny rule, so an action stays allowed as long as one binding still grants it. To remove an action, you must find every binding that gives it to the identity. A binding can name `shuttle` in three ways: as a ServiceAccount subject, as a User subject with the name `system:serviceaccount:starfleet-032-010-01-03:shuttle`, or through a group that every ServiceAccount of its namespace belongs to (`system:serviceaccounts:starfleet-032-010-01-03`).

List the RoleBindings in `outpost-032-010-01-03` with their subjects:

```sh
kubectl get rolebindings -n outpost-032-010-01-03 -o wide
```

```text
NAME                       ROLE                    AGE   USERS                                                   GROUPS                                           SERVICEACCOUNTS
shuttle-configmap-reader   Role/configmap-reader   11s                                                                                                            starfleet-032-010-01-03/shuttle
shuttle-pod-lister         Role/pod-lister         11s   system:serviceaccount:starfleet-032-010-01-03:shuttle                                                    
shuttle-view               ClusterRole/view        11s                                                                                                            starfleet-032-010-01-03/shuttle
starfleet-workloads        Role/pod-lister         11s                                                           system:serviceaccounts:starfleet-032-010-01-03   
```

Three bindings give Pod reads. `shuttle-view` gives the ClusterRole `view`, which includes Pod reads. `shuttle-pod-lister` names `shuttle` as a User. `starfleet-workloads` names the group of all ServiceAccounts in `starfleet-032-010-01-03`. Only `shuttle-configmap-reader` must stay.

## Remove the grants one at a time

Delete one binding and ask the API server again after each step. This shows that one remaining grant is enough to keep the action allowed.

```sh
kubectl delete rolebinding shuttle-view -n outpost-032-010-01-03
kubectl auth can-i list pods -n outpost-032-010-01-03 --as=system:serviceaccount:starfleet-032-010-01-03:shuttle
```

```text
rolebinding.rbac.authorization.k8s.io "shuttle-view" deleted from outpost-032-010-01-03 namespace
yes
```

The answer is still `yes`, because two other bindings grant the same action. Delete the User binding next:

```sh
kubectl delete rolebinding shuttle-pod-lister -n outpost-032-010-01-03
kubectl auth can-i list pods -n outpost-032-010-01-03 --as=system:serviceaccount:starfleet-032-010-01-03:shuttle
```

```text
rolebinding.rbac.authorization.k8s.io "shuttle-pod-lister" deleted from outpost-032-010-01-03 namespace
yes
```

The group binding still grants the action. Delete it too:

```sh
kubectl delete rolebinding starfleet-workloads -n outpost-032-010-01-03
kubectl auth can-i list pods -n outpost-032-010-01-03 --as=system:serviceaccount:starfleet-032-010-01-03:shuttle
```

```text
rolebinding.rbac.authorization.k8s.io "starfleet-workloads" deleted from outpost-032-010-01-03 namespace
no
```

## Check the result

Check all three read verbs on Pods and the ConfigMap read that must stay:

```sh
kubectl auth can-i get pods -n outpost-032-010-01-03 --as=system:serviceaccount:starfleet-032-010-01-03:shuttle
kubectl auth can-i watch pods -n outpost-032-010-01-03 --as=system:serviceaccount:starfleet-032-010-01-03:shuttle
kubectl auth can-i list configmaps -n outpost-032-010-01-03 --as=system:serviceaccount:starfleet-032-010-01-03:shuttle
kubectl get rolebindings -n outpost-032-010-01-03 -o wide
```

```text
no
no
yes
NAME                       ROLE                    AGE   USERS   GROUPS   SERVICEACCOUNTS
shuttle-configmap-reader   Role/configmap-reader   12s                    starfleet-032-010-01-03/shuttle
```

Pod reads are gone and the ConfigMap grant still works. Editing the Role `pod-lister` alone would not have been enough, because `view` also includes Pod reads. Deleting the bindings is the clean fix here: no other identity needs them.

## Common pitfalls

> [!WARNING]
> Do not stop after the first `kubectl auth can-i` answer that you expect. Check again after every change, because another binding can still grant the same action. Look at the USERS and GROUPS columns too, not only SERVICEACCOUNTS: a ServiceAccount can be named as a User or reached through its namespace group.
