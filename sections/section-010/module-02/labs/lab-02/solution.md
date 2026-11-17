---
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Remove Bindings To Broad Groups: Solution

Connect to the lab cluster first. Every command below uses this connection.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-010-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-010-02-02" || exit 1
```

## Confirm the finding

The RBAC (Role Based Access Control) authorizer checks every name of a request: the user name and each group. The API server adds groups on its own. Every authenticated request is in `system:authenticated`. Every ServiceAccount is also in `system:serviceaccounts` and in `system:serviceaccounts:<its namespace>`. A binding to one of these groups therefore reaches many identities at once.

Ask the API server as an ordinary user and as a ServiceAccount of an unrelated namespace. Any user name works with `--as`; the API server adds `system:authenticated` to it.

```sh
kubectl auth can-i list pods -n outpost-032-010-02-02 --as=ats-any-person
kubectl auth can-i get secrets -n outpost-032-010-02-02 --as=system:serviceaccount:default:default
```

```text
yes
yes
```

Both answers should be `no`. Some binding gives these identities access through a group.

## Search the bindings by group

Search by the subject, not by the binding name: a harmful binding can have any name. The `custom-columns` output prints the name, the role and the subject names of each binding, and `grep` keeps the lines with a broad group:

```sh
kubectl get clusterrolebindings -o custom-columns='NAME:.metadata.name,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name' | grep -E 'NAME|system:authenticated|system:unauthenticated|system:serviceaccounts'
kubectl get rolebindings -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name' | grep -E 'NAMESPACE|system:authenticated|system:unauthenticated|system:serviceaccounts'
```

The output below has its spaces shortened:

```text
NAME                                     ROLE                                     SUBJECTS
starfleet-automation                     edit                                     system:serviceaccounts:starfleet-032-010-02-02
system:basic-user                        system:basic-user                        system:authenticated
system:discovery                         system:discovery                         system:authenticated
system:public-info-viewer                system:public-info-viewer                system:authenticated,system:unauthenticated
system:service-account-issuer-discovery  system:service-account-issuer-discovery  system:serviceaccounts
NAMESPACE               NAME           ROLE           SUBJECTS
outpost-032-010-02-02   everyone-view  view           system:authenticated
outpost-032-010-02-02   fleet-config   secret-reader  system:serviceaccounts
```

Read each line and ask what the role allows. The four `system:` ClusterRoleBindings are built in. Kubernetes creates them at startup, and their roles only allow discovery, version information and self-checks, so they stay. The other three are findings:

- `everyone-view` gives `view` in `outpost-032-010-02-02` to every authenticated identity.
- `fleet-config` gives `secret-reader` to every ServiceAccount in the cluster.
- `starfleet-automation` gives `edit` in every namespace to every ServiceAccount of `starfleet-032-010-02-02`, including `scout`.

## Delete the three bindings

None of the three bindings has a subject that needs it. The narrow grants of `shuttle` and `starfleet-crew` are separate bindings, so they are not affected.

```sh
kubectl delete rolebinding everyone-view fleet-config -n outpost-032-010-02-02
kubectl delete clusterrolebinding starfleet-automation
```

```text
rolebinding.rbac.authorization.k8s.io "everyone-view" deleted from outpost-032-010-02-02 namespace
rolebinding.rbac.authorization.k8s.io "fleet-config" deleted from outpost-032-010-02-02 namespace
clusterrolebinding.rbac.authorization.k8s.io "starfleet-automation" deleted
```

## Check the result

Repeat the first two checks, then check `scout`:

```sh
kubectl auth can-i list pods -n outpost-032-010-02-02 --as=ats-any-person
kubectl auth can-i get secrets -n outpost-032-010-02-02 --as=system:serviceaccount:default:default
kubectl auth can-i get secrets -n outpost-032-010-02-02 --as=system:serviceaccount:starfleet-032-010-02-02:scout
kubectl auth can-i create deployments -n outpost-032-010-02-02 --as=system:serviceaccount:starfleet-032-010-02-02:scout
kubectl auth can-i list pods -n starfleet-032-010-02-02 --as=system:serviceaccount:starfleet-032-010-02-02:scout
```

```text
no
no
no
no
no
```

Then confirm that the narrow grants still work. The `--as-group` flag adds the group `starfleet-crew` to the request:

```sh
kubectl auth can-i list configmaps -n outpost-032-010-02-02 --as=system:serviceaccount:starfleet-032-010-02-02:shuttle
kubectl auth can-i list pods -n outpost-032-010-02-02 --as=jane --as-group=starfleet-crew
```

```text
yes
yes
```

A new run of the ClusterRoleBinding search now prints only the header and the four built-in `system:` bindings. The broad groups reach nothing beyond what Kubernetes itself needs.

## Common pitfalls

> [!WARNING]
> Do not delete the built-in `system:` bindings to clean up the list. Kubernetes recreates them at startup, and without them clients cannot run discovery. Search by subject, not by a name prefix such as `everyone-`: a binding to `system:authenticated` can have any name and can live in any namespace.
