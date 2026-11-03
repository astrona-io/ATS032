---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Remove Wildcards From A Group Role Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig contains the cluster address and credentials used by kubectl, the Kubernetes command-line tool. The lab has a separate kind cluster from the module playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-010-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-010-03-01" || exit 1
```

Keep this connection selected for every command below.

## Diagnose The Starting State

The `starfleet` and `outpost` namespaces exist. In `outpost`, the Role `crew-operator` uses the wildcard `*` for API groups, resources and verbs, and the RoleBinding `outpost-crew-operator` gives it to the group `outpost-crew`. A group is a set of users named in the identity that authentication produces. The crew only needs to read Pods, Services and ConfigMaps and to manage Deployments in `outpost`.

Act as a member of the group and try an action that the crew does not need:

```sh
kubectl auth can-i get secrets -n outpost --as=jane --as-group=outpost-crew
kubectl -n outpost get role crew-operator -o yaml
```

The first command prints `yes`, because the wildcard matches Secrets. The second command shows the rule with `'*'` in all three lists. Role-Based Access Control (RBAC) has no deny rule, so the only way to remove the access is to replace the rule.

## Replace The Rule

Save this as `crew-operator.yaml`. It has the same name and namespace as the existing Role, so `kubectl apply` updates it in place and the RoleBinding keeps working:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: crew-operator
  namespace: outpost
rules:
- apiGroups:
  - ''
  resources:
  - pods
  - services
  - configmaps
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - apps
  resources:
  - deployments
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete
```

Apply it:

```sh
kubectl apply -f crew-operator.yaml
```

## Verify The Result

Observe the actual result with these bounded checks. No example transcript is provided as evidence of a completed run.

```sh
kubectl auth can-i list pods -n outpost --as=jane --as-group=outpost-crew
kubectl auth can-i delete deployments.apps -n outpost --as=jane --as-group=outpost-crew
kubectl auth can-i get secrets -n outpost --as=jane --as-group=outpost-crew
kubectl auth can-i get pods/log -n outpost --as=jane --as-group=outpost-crew
kubectl auth can-i list pods -n starfleet --as=jane --as-group=outpost-crew
```

The first two commands print `yes`. The other three print `no`. Pod logs are the subresource `pods/log`, so the rule for `pods` does not cover them. The denied answers exit with status 1, which is expected.

After recording your result, remove this lab with `astrona destroy ats-032-lab-010-03-01`.

## Common pitfalls

> [!WARNING]
> - **Replacing `*` in resources but keeping `*` in verbs.** The Role still allows every action on the listed resources.
> - **Forgetting the `apps` group.** Deployments are not in the core group, so a rule with `apiGroups: ['']` does not match them.
> - **Expecting `pods` to include `pods/log` and `pods/exec`.** Subresources need their own entries, and the task does not allow them.
> - **Deleting the Role and creating a new one with another name.** The RoleBinding then points at a Role that does not exist.
