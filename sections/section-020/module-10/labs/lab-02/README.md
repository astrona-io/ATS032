# Replace a Legacy Token Secret With a Projected Token

Author notes for the graded lab `ats-032-lab-020-01-02`. The learner recreates the Pod `ledger-client` with a projected ServiceAccount token for the audience `ledger` that expires after at most 600 seconds, and deletes the long-lived Secret `reporter-legacy-token`. The grader reads the token file with `kubectl exec`, decodes its claims and sends it to the API server in a TokenReview. The token is never printed.

The learner reads `question.md` and the walkthrough `solution.md`. The lab runs in
its own kind cluster (one control plane, one worker) and uses the namespaces
named in `question.md`.

## Outcomes

Each outcome has its own grader in `validation/`, which runs `validate.sh <outcome>`
and prints one `PASS:` or `FAIL:` line. The checks live in `testing/live.py`.

- `legacy-secret-removed` (1 point): No long-lived token Secret for the ServiceAccount reporter is left in the namespace.
- `projected-ledger-token` (2 points): The Pod ledger-client holds a projected reporter token for the audience ledger that expires within 600 seconds.

## Files

- `bootstrap/setup.sh` creates the starting state from `bootstrap/manifests/`.
- `solution/apply.sh` applies the reference solution from `solution/`.
- `testing/verify-start.sh`, `testing/wait-solved.sh` and `testing/check.py` are the
  shared copies from `scripts/ci/lab-files/`; do not edit them here.

## Verify

```sh
astrona validate sections/section-020/module-10/labs/lab-02 --accept-terms --headless
astrona test sections/section-020/module-10/labs/lab-02 --accept-terms --headless
```
