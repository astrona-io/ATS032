# Disable Unneeded ServiceAccount Tokens

Author notes for the graded lab `ats-032-lab-020-01-01`. The learner creates the ServiceAccount `no-api` without token mounting and recreates the Pod `no-token-reader` so that its container has no ServiceAccount token. The grader checks the token directory with `kubectl exec`, and checks permissions with a SelfSubjectRulesReview compared to a ServiceAccount that has no bindings.

The learner reads `question.md` and the walkthrough `solution.md`. The lab runs in
its own kind cluster (one control plane, one worker) and uses the namespaces
named in `question.md`.

## Outcomes

Each outcome has its own grader in `validation/`, which runs `validate.sh <outcome>`
and prints one `PASS:` or `FAIL:` line. The checks live in `testing/live.py`.

- `no-api-serviceaccount` (1 point): The ServiceAccount no-api turns token mounting off and has no permissions of its own.
- `no-token-reader-pod` (1 point): The Pod no-token-reader runs as no-api with Pod-level mounting off and has no token in its container.

## Files

- `bootstrap/setup.sh` creates the starting state from `bootstrap/manifests/`.
- `solution/apply.sh` applies the reference solution from `solution/`.
- `testing/verify-start.sh`, `testing/wait-solved.sh` and `testing/check.py` are the
  shared copies from `scripts/ci/lab-files/`; do not edit them here.

## Verify

```sh
astrona validate sections/section-020/module-10/labs/lab-01 --accept-terms --headless
astrona test sections/section-020/module-10/labs/lab-01 --accept-terms --headless
```
