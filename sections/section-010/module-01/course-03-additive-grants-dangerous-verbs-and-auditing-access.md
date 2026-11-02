---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Additive Grants, Dangerous Verbs And Auditing Access

Hardening RBAC means finding and removing access, not only adding it. Two facts make that harder than it looks. RBAC has no deny rule, so removing one grant does not help while a second grant allows the same action. And some verbs give much more than their names suggest. This part removes a grant while another one stays, lists the permissions to treat with care, and shows the commands that list who can do what.

## Grants add up and nothing subtracts

The RBAC authorizer allows a request when any rule from any applicable binding matches. The applicable bindings are the ones that name the user, one of its groups, or a ServiceAccount. A ServiceAccount is automatically a member of the groups `system:serviceaccounts` and `system:serviceaccounts:<namespace>`, and every authenticated identity is a member of `system:authenticated`. A binding to any of those groups reaches the ServiceAccount too. The effective permission is the union of all matching rules. There is no rule that says "deny".

<!-- astrona:playground:renew -->

The playground shows this with a second path to the same permission. A RoleBinding named `shuttle-view` in `outpost`, which binds the `view` ClusterRole to `shuttle`, lets `shuttle` list Pods there. Save this as `role-pod-lister.yaml` to add another one:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-lister
  namespace: outpost
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: shuttle-pod-lister
  namespace: outpost
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-lister
subjects:
  - kind: ServiceAccount
    name: shuttle
    namespace: starfleet
```

If that binding does not exist yet, create it with `kubectl -n outpost create rolebinding shuttle-view --clusterrole=view --serviceaccount=starfleet:shuttle`. Then apply the Role:

```sh
kubectl apply -f role-pod-lister.yaml
```

Now remove the first path and test again. The first command deletes the binding of `view`. The second asks whether `shuttle` can still list Pods in `outpost`:

```sh
kubectl -n outpost delete rolebinding shuttle-view
kubectl auth can-i list pods -n outpost --as=system:serviceaccount:starfleet:shuttle
```

The answer is still `yes`, because `shuttle-pod-lister` allows the same action. Delete the second binding and ask again:

```sh
kubectl -n outpost delete rolebinding shuttle-pod-lister
kubectl auth can-i list pods -n outpost --as=system:serviceaccount:starfleet:shuttle
```

Now the answer is `no`. To remove an action from an identity, you must find and remove every binding that grants it. Changing one Role is not enough if another Role, a ClusterRole or a group binding still matches.

## Permissions that give more than they say

Some rules look harmless and are not. When you review a Role, check the effect of each rule and not only the verb.

- `get`, `list` or `watch` on `secrets`. Secrets hold passwords, tokens and keys. `list` and `watch` return the full content of every Secret in the scope, so they are as sensitive as `get`.
- `create` on `pods`. A Pod can mount any Secret and any ServiceAccount token of its namespace. The creator can read them from inside the container, even without permission to read Secrets directly.
- `pods/exec` and `pods/attach`. They run commands in an existing container with its mounted credentials.
- `create` on `serviceaccounts/token`. It requests a token for any ServiceAccount of the namespace and so acts as that account.
- `escalate`, `bind` and `impersonate`. The first two remove the escalation check. `impersonate` lets the holder send requests as another user, group or ServiceAccount.
- `nodes/proxy`. It reaches the kubelet API on a node.
- The wildcard `*` in `verbs`, `resources` or `apiGroups`. It also matches resources that do not exist yet, such as those added by a new custom resource definition.
- Binding a role to `system:authenticated`, `system:unauthenticated` or `system:serviceaccounts`. Every identity in that group receives the grant.

The reason to read `create pods` as a Secret-read permission is the mechanism, not the verb: the Pod's own volumes are the path to the data. A namespace where Pod creation is allowed but Secret reading is not is therefore only partly protected.

## List who can do what

Reviewing RBAC is a read task. Start from the identity or from the binding. The commands below do both. The first one lists all effective rules of `shuttle` in `outpost`. The second lists the RoleBindings of the namespace with their subjects. The third lists ClusterRoleBindings, so you can look for broad subjects.

```sh
kubectl auth can-i --list -n outpost --as=system:serviceaccount:starfleet:shuttle
kubectl get rolebindings -n outpost -o wide
kubectl get clusterrolebindings -o wide
```

The first command prints a table with the columns `Resources`, `Non-Resource URLs`, `Resource Names` and `Verbs`. It includes a few rules that every authenticated identity receives, such as the right to ask what its own permissions are, and the rules of any other grants you created in `outpost`. The `-o wide` output of the other two commands adds columns for the role and for the users, groups and ServiceAccounts in each binding. In the ClusterRoleBinding list, look for `cluster-admin` and for the subjects that are groups.

To compare a file with the live objects before you change anything, `kubectl diff -f` shows what an apply would change. `kubectl auth reconcile -f` applies a Role and binding file and also creates missing parts or adds missing rules, but it does not remove anything unless you ask it to.

Now you can find the second path that keeps an action alive, you know which rules grant indirect authority, and you can list the grants of an identity. The reading of an RBAC change then ends with one question: which bindings still apply to this identity after the change?

## Common pitfalls

> [!WARNING]
> - **Deleting one binding and calling the access removed.** Another binding, a ClusterRole or a group can still allow it. Test again with `kubectl auth can-i`.
> - **Allowing `create pods` but not Secrets.** A Pod can mount the Secrets of its namespace.
> - **Using a wildcard in a rule.** It covers resources and verbs that appear later.
> - **Binding to `system:authenticated`.** It gives the grant to every identity that can log in.
> - **Reviewing only Roles.** Check ClusterRoleBindings too, because they apply in every namespace.
