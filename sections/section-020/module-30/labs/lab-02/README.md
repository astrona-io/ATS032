# Remove Long-Lived ServiceAccount Tokens

Author notes for the graded lab `ats-032-lab-020-03-02`. The learner finds and deletes every Secret of type `kubernetes.io/service-account-token` in the namespace, keeps an ordinary Secret, and recreates the Pod `ledger-client` with a projected token that lives at most one hour. The grader reads the token file with `kubectl exec`, checks its lifetime claims and sends it to the API server in a TokenReview, without printing it.

The learner reads `question.md` and the walkthrough `solution.md`. The lab runs in
its own kind cluster (one control plane, one worker) and uses the namespaces
named in `question.md`.

## Outcomes

Each outcome has its own grader in `validation/`, which runs `validate.sh <outcome>`
and prints one `PASS:` or `FAIL:` line. The checks live in `testing/live.py`.

- `legacy-token-secrets-removed` (1 point): No Secret of type kubernetes.io/service-account-token is left in the namespace, and the Secret ledger-settings is kept.
- `ledger-client-short-token` (2 points): The Pod ledger-client holds a projected ledger token that expires within 3600 seconds.

## Files

- `bootstrap/setup.sh` creates the starting state from `bootstrap/manifests/`.
- `solution/apply.sh` applies the reference solution from `solution/`.
- `testing/verify-start.sh`, `testing/wait-solved.sh` and `testing/check.py` are the
  shared copies from `scripts/ci/lab-files/`; do not edit them here.

## Verify

```sh
astrona validate sections/section-020/module-30/labs/lab-02 --accept-terms --headless
astrona test sections/section-020/module-30/labs/lab-02 --accept-terms --headless
```
