# Remove Wildcards From A Group Role (author notes)

Graded lab `ats-032-lab-010-03-01`. The learner task is `question.md` and the walkthrough is `solution.md`.

- Start: Role `crew-operator` in `outpost-032-010-03-01` with `*`/`*`/`*`, bound to Group `outpost-crew` by `outpost-crew-operator`; RoleBinding `crew-maintenance` in `starfleet-032-010-03-01` gives `edit` to the same group.
- Guard (every outcome): `outpost-crew-operator` still references Role `crew-operator` and names only Group `outpost-crew`.
- Outcomes (one point each):
  - `least-privilege-rules`: no `*` in any field of the Role's rules, and the expanded rule set equals the required set (any split of the rules is accepted).
  - `excess-denied`: the effective rules of `jane` + `outpost-crew` (rules review minus a baseline user) equal the required set in outpost and are empty in starfleet; the group cannot list nodes; no binding other than `outpost-crew-operator` names the group.
- `testing/check.py`, `testing/verify-start.sh`, `testing/wait-solved.sh` and the `validation/` wrappers are copies of `scripts/ci/lab-files/`; do not edit them here.
