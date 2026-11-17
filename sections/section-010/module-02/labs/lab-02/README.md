# Remove Bindings To Broad Groups (author notes)

Graded lab `ats-032-lab-010-02-02`. The learner task is `question.md` and the walkthrough is `solution.md`.

- Start: `everyone-view` (ClusterRole `view` to `system:authenticated`) and `fleet-config` (Role `secret-reader` to `system:serviceaccounts`) in `outpost-032-010-02-02`, and the ClusterRoleBinding `starfleet-automation` (`edit` to `system:serviceaccounts:starfleet-032-010-02-02`). `shuttle-configmap-reader` and `crew-view` must stay.
- Guards (every outcome): `shuttle` lists ConfigMaps in outpost; `jane` in `starfleet-crew` lists Pods in outpost; the four built-in ClusterRoleBindings `system:basic-user`, `system:discovery`, `system:public-info-viewer` and `system:service-account-issuer-discovery` exist with their role and groups.
- Outcomes (one point each):
  - `authenticated-grant-removed`: an arbitrary user cannot list Pods or get ConfigMaps in outpost, and no binding outside the built-in four names Group `system:authenticated` or `system:unauthenticated`.
  - `serviceaccount-grants-removed`: `scout` cannot get Secrets or create Deployments in outpost or list Pods in starfleet; `default/default` cannot get Secrets in outpost; no binding outside the built-in four names `system:serviceaccounts` or the lab namespaces' ServiceAccount groups.
- The scan covers every ClusterRoleBinding and the RoleBindings of the two lab namespaces only, so other labs on a shared exam cluster do not affect it. `starfleet-automation` reaches only this lab's ServiceAccounts, but it is a cluster-scoped object, so the lab's exam scope is `cluster`.
- `testing/check.py`, `testing/verify-start.sh`, `testing/wait-solved.sh` and the `validation/` wrappers are copies of `scripts/ci/lab-files/`; do not edit them here.
