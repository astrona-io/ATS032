---
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Fix The Subjects Of A RoleBinding: Solution

Connect to the lab cluster first. Every command below uses this connection.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-010-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-010-03-02" || exit 1
```

## Confirm the problem

A subject is the identity that a binding gives its role to. RBAC (Role Based Access Control) compares subject names as exact strings. It does not check that a user or group exists, and it does not ignore letter case. Test each of the three intended subjects. The `--as-group` flag adds a group to the request, and `system:serviceaccount:<namespace>:<name>` is the user name of a ServiceAccount:

```sh
kubectl auth can-i list pods -n outpost-032-010-03-02 --as=jane
kubectl auth can-i list pods -n outpost-032-010-03-02 --as=anyone --as-group=outpost-observers
kubectl auth can-i list pods -n outpost-032-010-03-02 --as=system:serviceaccount:starfleet-032-010-03-02:probe
```

```text
no
no
no
```

## Read the subjects

The wide output of a RoleBinding lists its subjects by kind:

```sh
kubectl get rolebinding observers -n outpost-032-010-03-02 -o wide
```

```text
NAME        ROLE               AGE   USERS         GROUPS             SERVICEACCOUNTS
observers   ClusterRole/view   14s   Jane, ghost   outpost-observer   outpost-032-010-03-02/probe
```

Each subject has a mistake:

- The user `Jane` starts with a capital letter, so the API server treats it as a different user from `jane`.
- The user `ghost` is not one of the three subjects and must go.
- The group `outpost-observer` is missing the last `s`.
- The ServiceAccount `probe` points at `outpost-032-010-03-02`. A ServiceAccount subject needs the namespace where the ServiceAccount lives, which is `starfleet-032-010-03-02`.

## Replace the subjects

The `roleRef` of a binding cannot change after creation, but the `subjects` list can. Write the whole binding with the same name and role, and the correct subjects.

Save this as `rolebinding-observers.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: observers
  namespace: outpost-032-010-03-02
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
subjects:
  - kind: User
    name: jane
    apiGroup: rbac.authorization.k8s.io
  - kind: Group
    name: outpost-observers
    apiGroup: rbac.authorization.k8s.io
  - kind: ServiceAccount
    name: probe
    namespace: starfleet-032-010-03-02
```

Apply it:

```sh
kubectl apply -f rolebinding-observers.yaml
```

```text
rolebinding.rbac.authorization.k8s.io/observers configured
```

The `kubectl apply` command replaces the whole `subjects` list, so the four wrong entries are gone.

## Check the result

Then check the result. Read the binding again:

```sh
kubectl get rolebinding observers -n outpost-032-010-03-02 -o wide
```

```text
NAME        ROLE               AGE   USERS   GROUPS              SERVICEACCOUNTS
observers   ClusterRole/view   15s   jane    outpost-observers   starfleet-032-010-03-02/probe
```

Test the three subjects and the four old names:

```sh
kubectl auth can-i list pods -n outpost-032-010-03-02 --as=jane
kubectl auth can-i list pods -n outpost-032-010-03-02 --as=anyone --as-group=outpost-observers
kubectl auth can-i list pods -n outpost-032-010-03-02 --as=system:serviceaccount:starfleet-032-010-03-02:probe
kubectl auth can-i list pods -n outpost-032-010-03-02 --as=Jane
kubectl auth can-i list pods -n outpost-032-010-03-02 --as=ghost
kubectl auth can-i list pods -n outpost-032-010-03-02 --as=anyone --as-group=outpost-observer
kubectl auth can-i list pods -n outpost-032-010-03-02 --as=system:serviceaccount:outpost-032-010-03-02:probe
```

```text
yes
yes
yes
no
no
no
no
```

The three intended subjects can now list Pods, and the old names cannot. The group test uses the user name `anyone`, which shows that the group alone carries the grant.

## Common pitfalls

> [!WARNING]
> A misspelled subject gives no error. The API server accepts the binding, and the access just never works. After you write a binding, always test each subject with `kubectl auth can-i`. For a ServiceAccount subject, the `namespace` field is the namespace of the ServiceAccount, not the namespace of the binding.
