---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Remove Wildcards From A Group Role

The security review found a Role with wildcards that is bound to a group of operators in `outpost`.

## Objective

Replace the wildcard rule with explicit resources and verbs, keep the group binding, and prove the allowed and denied actions as a user in the group.

## Starting state

The `starfleet` and `outpost` namespaces exist. In `outpost`, the Role `crew-operator` uses the wildcard `*` for API groups, resources and verbs, and the RoleBinding `outpost-crew-operator` gives it to the group `outpost-crew`. A group is a set of users named in the identity that authentication produces. The crew only needs to read Pods, Services and ConfigMaps and to manage Deployments in `outpost`.

Use a host shell with this lab's private kubeconfig. A kubeconfig contains the cluster address and credentials used by kubectl, the Kubernetes command-line tool. The lab has a separate kind cluster from the module playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-010-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-010-03-01" || exit 1
```

Keep this connection selected for every command below.

## Required result

Rewrite the Role `crew-operator` in `outpost` without any wildcard. It must grant `get`, `list` and `watch` on core Pods, Services and ConfigMaps, and `get`, `list`, `watch`, `create`, `update`, `patch` and `delete` on Deployments in the `apps` group. It must grant nothing else. Keep the RoleBinding `outpost-crew-operator` as it is: it must still bind the Role to the group `outpost-crew` only. Reading Secrets, creating or deleting Pods, reading Pod logs, running commands in Pods, creating RoleBindings, any access in `starfleet` and reading nodes must be denied.

## Verify the result

Inspect the Role and test as a member of the group with `--as=jane --as-group=outpost-crew`. The grader checks the rules for any wildcard and tests allowed and denied actions. A user name is enough for the test because RBAC does not check that the user exists.
