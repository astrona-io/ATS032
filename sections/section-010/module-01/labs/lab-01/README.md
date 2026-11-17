# Grant Namespace Pod Read Access (author notes)

Graded lab `ats-032-lab-010-01-01`. The learner task is `question.md` and the walkthrough is `solution.md`.

- Start: namespaces `starfleet-032-010-01-01` and `outpost-032-010-01-01`, ServiceAccount `shuttle` with no grant.
- Outcomes (`validation/validate-<outcome>.sh`, one point each):
  - `pod-reader-role`: the Role's rules, expanded to (API group, resource, name, verb) tuples, equal Pod `get`, `list`, `watch`. Any split of the rules passes.
  - `shuttle-binding`: the RoleBinding references `pod-reader` and names only `shuttle` (ServiceAccount or `system:serviceaccount:` User form). A SelfSubjectRulesReview as `shuttle`, minus a baseline ServiceAccount, equals Pod reads in starfleet and is empty in outpost. Node list is denied. No other binding in the cluster names `shuttle`.
- `testing/check.py`, `testing/verify-start.sh`, `testing/wait-solved.sh` and the `validation/` wrappers are copies of `scripts/ci/lab-files/`; do not edit them here.
- Check with `astrona validate` and `astrona test --accept-terms --headless` on this folder.
