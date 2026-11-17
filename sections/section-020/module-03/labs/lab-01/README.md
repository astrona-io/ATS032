# Remove Over-Broad ServiceAccount Bindings

Author notes for the graded lab `ats-032-lab-020-03-01`. The learner finds a ClusterRoleBinding that gives `edit` to the ServiceAccount `ledger` and two bindings that give `view` to the group of all ServiceAccounts in the namespace, removes them and gives `ledger` only `get` and `list` on ConfigMaps. The grader compares effective permissions, from a SelfSubjectRulesReview, to a ServiceAccount without bindings, in the lab namespace and in `default`. The lab changes ClusterRoleBindings, so its exam scope is `cluster`.

The learner reads `question.md` and the walkthrough `solution.md`. The lab runs in
its own kind cluster (one control plane, one worker) and uses the namespaces
named in `question.md`.

## Outcomes

Each outcome has its own grader in `validation/`, which runs `validate.sh <outcome>`
and prints one `PASS:` or `FAIL:` line. The checks live in `testing/live.py`.

- `ledger-config-reader` (2 points): The ServiceAccount ledger can only get and list ConfigMaps in its namespace and has no access elsewhere.
- `archive-no-access` (1 point): The ServiceAccount archive has no permissions of its own.
- `group-bindings-removed` (1 point): No binding gives permissions to the group of all ServiceAccounts in the namespace.

## Files

- `bootstrap/setup.sh` creates the starting state from `bootstrap/manifests/`.
- `solution/apply.sh` applies the reference solution from `solution/`.
- `testing/verify-start.sh`, `testing/wait-solved.sh` and `testing/check.py` are the
  shared copies from `scripts/ci/lab-files/`; do not edit them here.

## Verify

```sh
astrona validate sections/section-020/module-03/labs/lab-01 --accept-terms --headless
astrona test sections/section-020/module-03/labs/lab-01 --accept-terms --headless
```
