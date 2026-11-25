# Reuse A ClusterRole In One Namespace And Delegate Role Management (author notes)

Graded lab `ats-032-lab-010-01-02`. The learner task is `question.md` and the walkthrough is `solution.md`.

- Start: namespaces `starfleet-032-010-01-02` and `outpost-032-010-01-02`, ServiceAccount `shuttle` with no grant.
- Outcomes (one point each):
  - `view-in-outpost`: RoleBinding `shuttle-view` references ClusterRole `view` and names only `shuttle`. `shuttle` can list Pods and get ConfigMaps in outpost, cannot get Secrets there, holds nothing in starfleet (rules review minus baseline) and no ClusterRoleBinding names it.
  - `role-manager`: the Role's rules equal `create`, `get`, `list` on `roles` and `rolebindings` as a set. `shuttle-role-manager` names only `shuttle`. `shuttle` holds nothing in outpost beyond `view` and the Role, holds no `escalate` or `bind`, and a server dry run as `shuttle` can create a Role for `get roles` but not one for `get secrets`. A live run on Kubernetes 1.35 showed that `--dry-run=server` runs the escalation check.
- `testing/check.py`, `testing/verify-start.sh`, `testing/wait-solved.sh` and the `validation/` wrappers are copies of `scripts/ci/lab-files/`; do not edit them here.
