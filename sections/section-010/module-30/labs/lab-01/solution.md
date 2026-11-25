---
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Remove Wildcards From A Group Role: Solution

Connect to the lab cluster first. Every command below uses this connection.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-010-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-010-03-01" || exit 1
```

## See what the group can do

A group is a name that authentication attaches to a user. RBAC (Role Based Access Control) does not check that a user or group exists, so you can test a group with any user name. The `--as` flag sets the user name and `--as-group` adds the group to the request:

```sh
kubectl auth can-i get secrets -n outpost-032-010-03-01 --as=jane --as-group=outpost-crew
kubectl auth can-i delete pods -n starfleet-032-010-03-01 --as=jane --as-group=outpost-crew
```

```text
yes
yes
```

The first answer comes from the wildcard Role. The second shows access in a namespace that the Role cannot reach, because a Role only works in its own namespace. So a second binding gives the group access in `starfleet-032-010-03-01`.

## Find every binding of the group

Search the bindings by subject name. The output below has its spaces shortened:

```sh
kubectl get rolebindings,clusterrolebindings -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name' | grep -E 'NAMESPACE|outpost-crew'
```

```text
NAMESPACE                 NAME                    ROLE           SUBJECTS
outpost-032-010-03-01     outpost-crew-operator   crew-operator  outpost-crew
starfleet-032-010-03-01   crew-maintenance        edit           outpost-crew
```

`outpost-crew-operator` stays; its Role needs new rules. `crew-maintenance` gives the built-in ClusterRole `edit` in `starfleet-032-010-03-01`, which the crew does not need.

## Rewrite the Role

Write one rule for each API group. Each rule lists only the resources and verbs the crew needs. Pods, Services and ConfigMaps are in the core API group, written as `""`. Deployments are in `apps`.

Save this as `role-crew-operator.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: crew-operator
  namespace: outpost-032-010-03-01
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

Apply it:

```sh
kubectl apply -f role-crew-operator.yaml
```

```text
role.rbac.authorization.k8s.io/crew-operator configured
```

The `kubectl apply` command replaces the whole `rules` list, so the wildcard rule is gone. The RoleBinding still points at the Role by name, so you do not change it.

## Remove the second grant

Delete the RoleBinding in `starfleet-032-010-03-01`:

```sh
kubectl delete rolebinding crew-maintenance -n starfleet-032-010-03-01
```

```text
rolebinding.rbac.authorization.k8s.io "crew-maintenance" deleted from starfleet-032-010-03-01 namespace
```

## Check the result

Then check the result. Test one allowed action and several actions the crew must not have:

```sh
kubectl auth can-i list deployments.apps -n outpost-032-010-03-01 --as=jane --as-group=outpost-crew
kubectl auth can-i get secrets -n outpost-032-010-03-01 --as=jane --as-group=outpost-crew
kubectl auth can-i create pods -n outpost-032-010-03-01 --as=jane --as-group=outpost-crew
kubectl auth can-i get pods --subresource=log -n outpost-032-010-03-01 --as=jane --as-group=outpost-crew
kubectl auth can-i create rolebindings -n outpost-032-010-03-01 --as=jane --as-group=outpost-crew
kubectl auth can-i delete pods -n starfleet-032-010-03-01 --as=jane --as-group=outpost-crew
```

```text
yes
no
no
no
no
no
```

The full list confirms that nothing else is left. The output below is shortened: the non-resource URL lines (`/api`, `/healthz`, `/version` and similar) come from built-in bindings for every authenticated user and are left out:

```sh
kubectl auth can-i --list -n outpost-032-010-03-01 --as=jane --as-group=outpost-crew
```

```text
Resources                                       Non-Resource URLs   Resource Names   Verbs
selfsubjectreviews.authentication.k8s.io        []                  []               [create]
selfsubjectaccessreviews.authorization.k8s.io   []                  []               [create]
selfsubjectrulesreviews.authorization.k8s.io    []                  []               [create]
deployments.apps                                []                  []               [get list watch create update patch delete]
configmaps                                      []                  []               [get list watch]
pods                                            []                  []               [get list watch]
services                                        []                  []               [get list watch]
```

The three `self...` lines are also built in: they let every authenticated user ask what it may do. The other four lines are exactly the crew's job.

## Common pitfalls

> [!WARNING]
> Removing the wildcards from the Role is not enough when the group has another binding. Always search the bindings by subject before you call a group least privilege. Also check the API group of each resource: a rule for `deployments` with `apiGroups: [""]` matches nothing, because Deployments live in `apps`.
