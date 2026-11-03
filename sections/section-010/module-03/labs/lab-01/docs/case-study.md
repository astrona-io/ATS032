---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Starting Environment

The `starfleet` and `outpost` namespaces exist. In `outpost`, the Role `crew-operator` uses the wildcard `*` for API groups, resources and verbs, and the RoleBinding `outpost-crew-operator` gives it to the group `outpost-crew`. A group is a set of users named in the identity that authentication produces. The crew only needs to read Pods, Services and ConfigMaps and to manage Deployments in `outpost`.

Rewrite the Role `crew-operator` in `outpost` without any wildcard. It must grant `get`, `list` and `watch` on core Pods, Services and ConfigMaps, and `get`, `list`, `watch`, `create`, `update`, `patch` and `delete` on Deployments in the `apps` group. It must grant nothing else. Keep the RoleBinding `outpost-crew-operator` as it is: it must still bind the Role to the group `outpost-crew` only. Reading Secrets, creating or deleting Pods, reading Pod logs, running commands in Pods, creating RoleBindings, any access in `starfleet` and reading nodes must be denied.
