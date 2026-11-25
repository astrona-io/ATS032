# Lock Down the Default ServiceAccount

Author notes for the graded lab `ats-032-lab-020-02-03`. The learner removes the bindings that give the `default` ServiceAccount permissions in two namespaces, turns token mounting off on both `default` ServiceAccounts and recreates the Pods `shuttle` and `drifter` so that they have no token. The grader checks effective permissions with a SelfSubjectRulesReview and runs `kubectl exec` in both Pods.

The learner reads `question.md` and the walkthrough `solution.md`. The lab runs in
its own kind cluster (one control plane, one worker) and uses the namespaces
named in `question.md`.

## Outcomes

Each outcome has its own grader in `validation/`, which runs `validate.sh <outcome>`
and prints one `PASS:` or `FAIL:` line. The checks live in `testing/live.py`.

- `default-grants-removed` (2 points): The default ServiceAccounts of both namespaces have no permissions of their own, and the Role pod-access is kept.
- `default-automount-off` (1 point): The default ServiceAccounts of both namespaces turn token mounting off.
- `pods-without-token` (1 point): The Pods shuttle and drifter run without a ServiceAccount token.

## Files

- `bootstrap/setup.sh` creates the starting state from `bootstrap/manifests/`.
- `solution/apply.sh` applies the reference solution from `solution/`.
- `testing/verify-start.sh`, `testing/wait-solved.sh` and `testing/check.py` are the
  shared copies from `scripts/ci/lab-files/`; do not edit them here.

## Verify

```sh
astrona validate sections/section-020/module-20/labs/lab-03 --accept-terms --headless
astrona test sections/section-020/module-20/labs/lab-03 --accept-terms --headless
```
