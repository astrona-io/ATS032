# Give a Deployment Its Own ServiceAccount

Author notes for the graded lab `ats-032-lab-020-02-01`. The learner creates the ServiceAccount `probe` without token mounting and moves the Deployment `probe` to it. The grader checks the rollout and runs `kubectl exec` in every Pod of the Deployment to confirm that no token directory exists.

The learner reads `question.md` and the walkthrough `solution.md`. The lab runs in
its own kind cluster (one control plane, one worker) and uses the namespaces
named in `question.md`.

## Outcomes

Each outcome has its own grader in `validation/`, which runs `validate.sh <outcome>`
and prints one `PASS:` or `FAIL:` line. The checks live in `testing/live.py`.

- `probe-serviceaccount` (1 point): The ServiceAccount probe turns token mounting off and has no permissions of its own.
- `probe-pods-without-token` (2 points): Every Pod of the Deployment probe runs as probe and has no ServiceAccount token.

## Files

- `bootstrap/setup.sh` creates the starting state from `bootstrap/manifests/`.
- `solution/apply.sh` applies the reference solution from `solution/`.
- `testing/verify-start.sh`, `testing/wait-solved.sh` and `testing/check.py` are the
  shared copies from `scripts/ci/lab-files/`; do not edit them here.

## Verify

```sh
astrona validate sections/section-020/module-02/labs/lab-01 --accept-terms --headless
astrona test sections/section-020/module-02/labs/lab-01 --accept-terms --headless
```
