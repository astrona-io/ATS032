---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Starting Environment

The namespaces `starfleet`, `outpost` and `dock` exist. The ServiceAccounts `scout` and `probe` live in `starfleet`. A ServiceAccount identifies a workload when it calls the Kubernetes application programming interface (API). A review found four problems. The ClusterRoleBinding `scout-edit-everywhere` gives `scout` the built-in `edit` ClusterRole in every namespace, but `scout` only reads Pods in `outpost` and updates the ConfigMap `scout-report` there. The ClusterRoleBinding `everyone-view` gives the built-in `view` ClusterRole to the group `system:authenticated`. The Role `crew-operator` in `outpost` uses the wildcard `*` for API groups, resources and verbs and is bound to the group `outpost-crew`. The `probe` workload needs to read Pods and Services in `dock` and has no grant yet.

Fix all four problems and keep every other object as it is.

1. In `outpost`, create Role `scout-operator` with exactly two rules: `get`, `list` and `watch` on core Pods, and `get`, `update` and `patch` on the core ConfigMap named `scout-report` (use `resourceNames`). Create RoleBinding `scout-operator` that binds only `scout` to it. Delete ClusterRoleBinding `scout-edit-everywhere`. No ClusterRoleBinding may name `scout` afterwards.
2. Delete ClusterRoleBinding `everyone-view`. No ClusterRoleBinding you created may name the group `system:authenticated`.
3. Rewrite Role `crew-operator` in `outpost` without any wildcard: `get`, `list` and `watch` on core Pods, Services and ConfigMaps, and `get`, `list`, `watch`, `create`, `update`, `patch` and `delete` on Deployments in the `apps` group. Keep the RoleBinding `outpost-crew-operator` unchanged.
4. Create ClusterRoles `fleet-reader-pods` (`get`, `list`, `watch` on core Pods) and `fleet-reader-services` (the same verbs on core Services). Label both `fleet.example.com/aggregate-to-fleet-reader: "true"`. Create the aggregated ClusterRole `fleet-reader` with an `aggregationRule` whose only selector matches that label, and no `rules` of its own. Create RoleBinding `probe-fleet-reader` in `dock` that binds only `probe` to `fleet-reader`.

Then the following must hold. `scout` can list Pods and update `scout-report` in `outpost` and cannot read Secrets, create ConfigMaps or list Pods in `starfleet`. A user in the group `outpost-crew` can list Pods and create Deployments in `outpost`, and cannot read Secrets, create Pods, read Pod logs or list Pods in `starfleet`. `probe` can list Pods and read Services in `dock`, and cannot create Pods or read Secrets there or list Pods in `outpost` or `starfleet`.
