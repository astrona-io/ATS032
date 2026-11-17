# Triage Vulnerability Records And Label Patch Waves

Author notes for the graded lab `ats-032-lab-040-02-02`. The learner reads `question.md` and,
after the attempt, `solution.md`.

- `bootstrap/setup.sh` starts the Deployment `probe` with a `busybox` tag that
  it picks at random, reads the kubelet, `etcd` and CoreDNS versions, and runs
  `bootstrap/feed.py`. The script writes eight made-up records, two per
  component. Each record is affected, already fixed (FIXED equals the running
  version) or not yet introduced. At least two records are affected and at
  least two are not.
- `testing/live.py` reads the feed and the running versions on every run,
  applies the rule from the task and compares the result with the learner's
  list as a set. Nothing in the lab stores an answer key.
- `solution/apply.sh` is the reference solution that `astrona test` applies.
- The lab labels nodes, so its `examScope` is `cluster`.

Run `astrona validate .` and `astrona test . --accept-terms --headless` in this
folder. `testing/verify-start.sh` checks that every outcome fails on the
starting state; after the reference solution every outcome must pass.
