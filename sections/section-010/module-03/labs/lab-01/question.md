---
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Remove Wildcards From A Group Role

Allow about 10 minutes for the tasks.

This lab runs in its own kind cluster. Connect to it first:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-010-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-010-03-01" || exit 1
```

A security review found that the group `outpost-crew` can do almost anything in `outpost-032-010-03-01`. The RoleBinding `outpost-crew-operator` gives the group the Role `crew-operator`, and that Role uses the wildcard `*` for API groups, resources and verbs. The crew only needs to read Pods, Services and ConfigMaps and to manage Deployments in `outpost-032-010-03-01`. The group may hold other grants too.

1. Rewrite the Role `crew-operator` in `outpost-032-010-03-01` without any wildcard. It must grant exactly `get`, `list` and `watch` on Pods, Services and ConfigMaps (core API group), and `get`, `list`, `watch`, `create`, `update`, `patch` and `delete` on Deployments (API group `apps`), and nothing else.
2. Keep the RoleBinding `outpost-crew-operator` as it is: it binds the Role `crew-operator` to the group `outpost-crew` only.
3. Remove every other grant of the group `outpost-crew`, so that `outpost-crew-operator` is the only binding in the cluster that names it. After this, a member of the group must hold only the actions of task 1 in `outpost-032-010-03-01`, nothing in `starfleet-032-010-03-01`, and it must not list nodes.
