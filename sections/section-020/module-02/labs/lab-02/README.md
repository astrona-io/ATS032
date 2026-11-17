# Grant a ServiceAccount Least-Privilege Access

Author notes for the graded lab `ats-032-lab-020-02-02`. The learner creates the ServiceAccount `shuttle-reader`, gives it only `get` and `list` on Pods in `starfleet-032-020-02-02`, and recreates the Pod `shuttle` with a short-lived projected token. The grader compares the permissions of `shuttle-reader` to a ServiceAccount without bindings in both namespaces, and sends the token from the Pod to the API server in a TokenReview without printing it.

The learner reads `question.md` and the walkthrough `solution.md`. The lab runs in
its own kind cluster (one control plane, one worker) and uses the namespaces
named in `question.md`.

## Outcomes

Each outcome has its own grader in `validation/`, which runs `validate.sh <outcome>`
and prints one `PASS:` or `FAIL:` line. The checks live in `testing/live.py`.

- `shuttle-reader-access` (2 points): The ServiceAccount shuttle-reader can only get and list Pods in starfleet and has no extra access in outpost.
- `shuttle-projected-token` (1 point): The Pod shuttle runs as shuttle-reader with only a short-lived projected token at /var/run/tokens/token.

## Files

- `bootstrap/setup.sh` creates the starting state from `bootstrap/manifests/`.
- `solution/apply.sh` applies the reference solution from `solution/`.
- `testing/verify-start.sh`, `testing/wait-solved.sh` and `testing/check.py` are the
  shared copies from `scripts/ci/lab-files/`; do not edit them here.

## Verify

```sh
astrona validate sections/section-020/module-02/labs/lab-02 --accept-terms --headless
astrona test sections/section-020/module-02/labs/lab-02 --accept-terms --headless
```
