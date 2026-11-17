# Fix The Subjects Of A RoleBinding (author notes)

Graded lab `ats-032-lab-010-03-02`. The learner task is `question.md` and the walkthrough is `solution.md`.

- Start: RoleBinding `observers` in `outpost-032-010-03-02` gives ClusterRole `view` to User `Jane`, User `ghost`, Group `outpost-observer` and ServiceAccount `outpost-032-010-03-02/probe`. The ServiceAccount `probe` exists in `starfleet-032-010-03-02`.
- Guard (every outcome): `observers` exists and references ClusterRole `view`.
- Outcomes (one point each):
  - `user-subject`: `jane` can list Pods in outpost; `Jane` and `ghost` cannot; the only User subject is `jane` (the User form of the probe ServiceAccount is also accepted).
  - `group-subject`: a member of `outpost-observers` can list Pods; a member of `outpost-observer` cannot; the only Group subject is `outpost-observers`.
  - `serviceaccount-subject`: `system:serviceaccount:starfleet-032-010-03-02:probe` can list Pods; the outpost `probe` cannot; the binding names starfleet `probe` (ServiceAccount or User form) and no other ServiceAccount.
- Tested on the dev cluster: fixing only `Jane` and keeping `ghost` fails `user-subject`.
- `testing/check.py`, `testing/verify-start.sh`, `testing/wait-solved.sh` and the `validation/` wrappers are copies of `scripts/ci/lab-files/`; do not edit them here.
