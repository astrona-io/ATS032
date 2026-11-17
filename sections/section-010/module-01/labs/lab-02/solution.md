---
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Reuse A ClusterRole In One Namespace And Delegate Role Management: Solution

Connect to the lab cluster first. Every command below uses this connection.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-010-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-010-01-02" || exit 1
```

## Bind the ClusterRole view in one namespace

A ClusterRole is a set of RBAC (Role Based Access Control) rules that is defined once for the whole cluster. Its reach depends on the binding. A ClusterRoleBinding gives the rules in every namespace. A RoleBinding that references a ClusterRole gives the same rules only in the namespace of the RoleBinding. The built-in ClusterRole `view` allows reads of most namespaced objects, but not Secrets.

Save this as `rolebinding-shuttle-view.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: shuttle-view
  namespace: outpost-032-010-01-02
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
subjects:
  - kind: ServiceAccount
    name: shuttle
    namespace: starfleet-032-010-01-02
```

Apply it:

```sh
kubectl apply -f rolebinding-shuttle-view.yaml
```

```text
rolebinding.rbac.authorization.k8s.io/shuttle-view created
```

Then check the result. The `--as` flag sends each request as `shuttle`:

```sh
kubectl auth can-i list pods -n outpost-032-010-01-02 --as=system:serviceaccount:starfleet-032-010-01-02:shuttle
kubectl auth can-i get secrets -n outpost-032-010-01-02 --as=system:serviceaccount:starfleet-032-010-01-02:shuttle
kubectl auth can-i list pods -n starfleet-032-010-01-02 --as=system:serviceaccount:starfleet-032-010-01-02:shuttle
```

```text
yes
no
no
```

The first `yes` comes from `view` in `outpost-032-010-01-02`. Secrets stay denied because `view` has no rule for them. Pods in `starfleet-032-010-01-02` stay denied because the RoleBinding works only in its own namespace.

## Delegate Role management without escalation

The API server protects RBAC with an escalation check. When an identity creates a Role, the API server allows it only if the identity already holds every permission in that Role, or holds the verb `escalate`. When it creates a RoleBinding, the identity must hold every permission of the referenced role, or hold the verb `bind`. So a Role that allows `create` on Roles is safe as long as it does not also allow `escalate` or `bind`.

Save this as `role-role-manager.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: role-manager
  namespace: outpost-032-010-01-02
rules:
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["roles", "rolebindings"]
    verbs: ["create", "get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: shuttle-role-manager
  namespace: outpost-032-010-01-02
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: role-manager
subjects:
  - kind: ServiceAccount
    name: shuttle
    namespace: starfleet-032-010-01-02
```

Apply it:

```sh
kubectl apply -f role-role-manager.yaml
```

```text
role.rbac.authorization.k8s.io/role-manager created
rolebinding.rbac.authorization.k8s.io/shuttle-role-manager created
```

Then check the result. `shuttle` may create Roles, but it does not hold the two verbs that skip the escalation check:

```sh
kubectl auth can-i create roles -n outpost-032-010-01-02 --as=system:serviceaccount:starfleet-032-010-01-02:shuttle
kubectl auth can-i escalate roles -n outpost-032-010-01-02 --as=system:serviceaccount:starfleet-032-010-01-02:shuttle
kubectl auth can-i bind roles -n outpost-032-010-01-02 --as=system:serviceaccount:starfleet-032-010-01-02:shuttle
```

```text
yes
no
no
```

Now let the API server run the escalation check itself. The flag `--dry-run=server` sends the full create request, so the API server runs every check, but it stores nothing. The first Role asks for ConfigMap reads, which `shuttle` holds through `view`. The second asks for Secret reads, which `shuttle` does not hold.

```sh
kubectl create role copy-reader --verb=get --resource=configmaps -n outpost-032-010-01-02 --dry-run=server --as=system:serviceaccount:starfleet-032-010-01-02:shuttle
kubectl create role secret-reader --verb=get --resource=secrets -n outpost-032-010-01-02 --dry-run=server --as=system:serviceaccount:starfleet-032-010-01-02:shuttle
```

```text
role.rbac.authorization.k8s.io/copy-reader created (server dry run)
Error from server (Forbidden): roles.rbac.authorization.k8s.io "secret-reader" is forbidden: user "system:serviceaccount:starfleet-032-010-01-02:shuttle" (groups=["system:serviceaccounts" "system:serviceaccounts:starfleet-032-010-01-02" "system:authenticated"]) is attempting to grant RBAC permissions not currently held:
{APIGroups:[""], Resources:["secrets"], Verbs:["get"]}
```

The API server, not the RBAC authorizer's allow decision, refused the second Role: `shuttle` may create Roles, but only Roles inside what it already holds. The error also shows the groups that every ServiceAccount carries, which matter when you audit group bindings.

## Common pitfalls

> [!WARNING]
> A ClusterRoleBinding to `view` would also pass the checks in `outpost-032-010-01-02`, but it gives the same reads in every namespace. Use a RoleBinding whenever the access belongs to one namespace. Never add `escalate` or `bind` to a delegated role: with either verb, the holder can grant itself any permission in that namespace.
