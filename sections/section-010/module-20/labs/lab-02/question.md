---
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Remove Bindings To Broad Groups

Allow about 10 minutes for the tasks.

This lab runs in its own kind cluster. Connect to it first:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-010-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-010-02-02" || exit 1
```

A review of `outpost-032-010-02-02` found that any signed-in identity can read its objects, and that ServiceAccounts which have no business there can read its Secrets. The cause is bindings to broad groups: groups that the API server adds to many identities at once, such as `system:authenticated` (every authenticated request), `system:serviceaccounts` (every ServiceAccount) and `system:serviceaccounts:<namespace>` (every ServiceAccount of one namespace). The ServiceAccounts `shuttle` and `scout` live in `starfleet-032-010-02-02`.

1. Remove every grant to `system:authenticated` or `system:unauthenticated` that is not one of the built-in `system:` ClusterRoleBindings. After this, an ordinary signed-in user must not list Pods or read ConfigMaps in `outpost-032-010-02-02`.
2. Remove every grant to `system:serviceaccounts` or to `system:serviceaccounts:starfleet-032-010-02-02` that is not one of the built-in `system:` ClusterRoleBindings. After this, `scout` must not read Secrets or create Deployments in `outpost-032-010-02-02`, or list Pods in `starfleet-032-010-02-02`, and no ServiceAccount of another namespace may read Secrets in `outpost-032-010-02-02`.
3. Do not change or delete the built-in ClusterRoleBindings `system:basic-user`, `system:discovery`, `system:public-info-viewer` and `system:service-account-issuer-discovery`.
4. Keep the RoleBindings `shuttle-configmap-reader` and `crew-view` in `outpost-032-010-02-02`, so `shuttle` still lists ConfigMaps there and the group `starfleet-crew` still has `view` there.
