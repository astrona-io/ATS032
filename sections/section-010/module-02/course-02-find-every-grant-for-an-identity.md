---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Find Every Grant That Reaches An Identity

A test with `kubectl auth can-i` tells you that an action is allowed, but not which binding allows it. To remove access you must delete or change that binding, and because RBAC has no deny rule, you must find all of them. This part builds a repeatable way to list every binding, search it for an identity and its groups, and expand the roles behind the matches.

## The names an identity answers to

A binding does not name an identity once. The RBAC authorizer collects every name that applies to the request, and any binding that names one of them counts. For a ServiceAccount the names are the user name `system:serviceaccount:<namespace>:<name>`, the group `system:serviceaccounts`, the group `system:serviceaccounts:<namespace>` and the group `system:authenticated`. For a person or a certificate the names are the user name and the groups from authentication, plus `system:authenticated`. A request without credentials is `system:anonymous` in the group `system:unauthenticated`.

So the review of `scout` cannot stop at bindings that contain the word `scout`. It must also look at bindings to `system:serviceaccounts:starfleet`, to `system:serviceaccounts` and to `system:authenticated`, because `scout` is a member of all three. A broad group is the place where unexpected access hides.

## List every binding in a form you can search

The default output of `kubectl get` hides the subjects. The `-o custom-columns` option prints the fields that you choose, and `[*]` in a path prints every item of a list. The first command lists the ClusterRoleBindings with the role and the subjects. The second lists the RoleBindings of all namespaces and adds the namespace column, because a RoleBinding grants access only in its own namespace.

<!-- astrona:playground:renew -->

```sh
kubectl get clusterrolebindings -o custom-columns=NAME:.metadata.name,ROLE:.roleRef.name,KIND:.subjects[*].kind,SUBJECT:.subjects[*].name
kubectl get rolebindings --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,ROLEKIND:.roleRef.kind,ROLE:.roleRef.name,KIND:.subjects[*].kind,SUBJECT:.subjects[*].name
```

The first list is long, because Kubernetes creates many bindings for its own components. Their names start with `system:`. The second list also contains RoleBindings that Kubernetes creates in the `kube-system` and `kube-public` namespaces. The two RoleBindings of `outpost` are in it, and so are `shuttle-configmap-reader` and `crew-view`. When a binding has several subjects, the columns print them separated by commas, in the same order.

## Search for the identity and for broad groups

On a real cluster you pipe the lists through `grep`. The first command finds bindings that name `scout`. The second uses the `-o wide` output, whose last columns show users, groups and ServiceAccounts as `namespace/name`, which separates a ServiceAccount `scout` in `starfleet` from one with the same name in another namespace. The third looks for the broad groups that every ServiceAccount or every authenticated identity belongs to.

```sh
kubectl get clusterrolebindings -o custom-columns=NAME:.metadata.name,ROLE:.roleRef.name,KIND:.subjects[*].kind,SUBJECT:.subjects[*].name | grep scout
kubectl get clusterrolebindings -o wide | grep starfleet/scout
kubectl get clusterrolebindings,rolebindings --all-namespaces -o wide | grep -E 'system:authenticated|system:unauthenticated|system:serviceaccounts'
```

The first two commands print the row of `scout-edit-everywhere` with the role `edit`. That is the binding that gives the cluster-wide access you saw in the previous tests. The third command prints rows that belong to Kubernetes itself: built-in bindings for discovery and basic user rights are meant to reach `system:authenticated`. During a review you read each row and ask whether its role is as small as the built-in ones. A binding of `edit`, `admin` or `cluster-admin` to one of these groups would be a finding.

## Expand the role behind the match

A binding only names a role. To know what it allows you read the role. For a custom Role, `kubectl describe` prints the rules as a table. For a built-in ClusterRole such as `edit`, the table is long, so ask the authorizer instead and read the result for the identity.

```sh
kubectl -n outpost describe role configmap-reader
kubectl auth can-i --list -n outpost --as=system:serviceaccount:starfleet:scout
```

The first command shows one rule: `configmaps` with the verbs `get` and `list`. The second prints the rules that `scout` has in `outpost`. It is long, and it contains rows for `secrets`, for `pods/exec` and for the write verbs that `edit` carries. Read the `Resources` and `Verbs` columns, and compare them with what the workload really does. The gap between the two is the exposure.

```mermaid
flowchart TB
    I["Identity"] -->|"user, groups"| N["All its names"]
    N -->|"search"| B["Bindings"]
    B -->|"roleRef"| R["Roles"]
    R -->|"rules"| E["Effective access"]
    E -->|"compare with need"| F["Findings"]
```

The diagram shows the order of a review: from the identity to all its names, to the bindings, to the roles, and then to a list of findings.

You can now list every grant behind an answer and know which groups to include. What is left is to change the grant without breaking the workload, which is the subject of the next part.

## Common pitfalls

> [!WARNING]
> - **Searching only for the ServiceAccount name.** Bindings to `system:serviceaccounts`, to the namespace group or to `system:authenticated` also apply.
> - **Searching only RoleBindings.** A ClusterRoleBinding applies in every namespace.
> - **Ignoring the namespace of a ServiceAccount.** Two ServiceAccounts with the same name in different namespaces are different identities.
> - **Reading the role name and not the rules.** A role with a harmless name can hold broad rules. Read the rules or test the actions.
> - **Treating `system:` bindings as safe because they are built in.** Check what each one grants, because a broad role bound to a broad group is a finding wherever it comes from.
