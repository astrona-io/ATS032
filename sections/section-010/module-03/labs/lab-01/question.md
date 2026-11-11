---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Remove Wildcards From A Group Role

Solve this question on: `terminal`

The security review found a Role with wildcards that is bound to a group of operators in `outpost-032-010-03-01`.

## Objective

Replace the wildcard rule with explicit resources and verbs, keep the group binding, and prove the allowed and denied actions as a user in the group.

## Starting state

The `starfleet-032-010-03-01` and `outpost-032-010-03-01` namespaces exist. In `outpost-032-010-03-01`, the Role `crew-operator` uses the wildcard `*` for API groups, resources and verbs, and the RoleBinding `outpost-crew-operator` gives it to the group `outpost-crew`. A group is a set of users named in the identity that authentication produces. The crew only needs to read Pods, Services and ConfigMaps and to manage Deployments in `outpost-032-010-03-01`.

Use a host shell with this lab's private kubeconfig. A kubeconfig contains the cluster address and credentials used by kubectl, the Kubernetes command-line tool. The lab has a separate kind cluster from the module playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-010-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-010-03-01" || exit 1
```

Keep this connection selected for every command below.

Allow 5–7 minutes for task work. Cluster startup adds time.

## Tasks

1. Rewrite the Role `crew-operator` in `outpost-032-010-03-01` without any wildcard. It grants `get`, `list` and `watch` on core Pods, Services and ConfigMaps, and `get`, `list`, `watch`, `create`, `update`, `patch` and `delete` on Deployments in the `apps` group, and nothing else.
2. Test as a member of the group with `--as=jane --as-group=outpost-crew`: the actions in task 1 are allowed. Reading Secrets, creating or deleting Pods, reading Pod logs, running commands in Pods, creating RoleBindings, any access in `starfleet-032-010-03-01` and reading nodes are denied.

## Constraints

- Keep the RoleBinding `outpost-crew-operator` as it is: it binds the Role to the group `outpost-crew` only.
- Do not add any other grant.

## How the answer is checked

The grader runs two checks. The first checks that the rules of `crew-operator` have no wildcard, grant exactly the resources and verbs in task 1, and that the group can perform them. The second asks the API server about each denied action in task 2 and fails if any is allowed. Both checks also confirm that the RoleBinding `outpost-crew-operator` is unchanged.

Hint: a user name is enough for the test because RBAC does not check that the user exists. Ask about a subresource with `kubectl auth can-i get pods --subresource=log`.
