# Rewrite A Broad Grant As Least Privilege (author notes)

Graded lab `ats-032-lab-010-02-01`. The learner task is `question.md` and the walkthrough is `solution.md`.

- Start: `scout` holds `edit` everywhere through the ClusterRoleBinding `scout-edit-everywhere`, and `edit` in `starfleet-032-010-02-01` through the RoleBinding `release-bot`, which names it as User `system:serviceaccount:starfleet-032-010-02-01:scout`. `shuttle-configmap-reader` and `crew-view` must stay.
- Guards (every outcome): `shuttle` can list ConfigMaps in outpost; `jane` in group `starfleet-crew` can list Services in outpost.
- Outcomes (one point each):
  - `scout-operator-role`: the Role's rules as a set equal Pod `get`, `list`, `watch` and `get`, `update`, `patch` on ConfigMap `scout-report`.
  - `scout-operator-binding`: references the Role, names only `scout` (either form), and `scout` can update `configmaps/scout-report`.
  - `cluster-grant-removed`: the rules review of `scout` minus a baseline ServiceAccount equals the Role in outpost and is empty in starfleet, node list is denied, and no binding other than `scout-operator` names `scout` in either form.
- The ClusterRoleBinding `scout-edit-everywhere` reaches only this lab's ServiceAccount, so the lab is safe on a shared exam cluster.
- `testing/check.py`, `testing/verify-start.sh`, `testing/wait-solved.sh` and the `validation/` wrappers are copies of `scripts/ci/lab-files/`; do not edit them here.
