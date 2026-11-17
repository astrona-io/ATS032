# Record A Cluster Version Inventory With Image Digests

Author notes for the graded lab `ats-032-lab-040-02-01`. The learner reads `question.md` and,
after the attempt, `solution.md`.

- `bootstrap/setup.sh` starts the Deployment `probe` with a `busybox` tag that
  it picks at random (`1.36.1` or `1.37.0`). Both tags are preloaded.
- `testing/live.py` reads every value from the live cluster on each run: the
  API server version, the node status, the `etcd` and CoreDNS images, the
  Deployment image and the `imageID` of the running Pods. It extracts the
  `sha256:` digest with a pattern, so both `sha256:...` and
  `name@sha256:...` forms of `imageID` work. Nothing in the lab stores an
  answer key.
- `solution/apply.sh` is the reference solution that `astrona test` applies.
- The lab only reads the cluster and writes one ConfigMap, so its `examScope`
  is `namespace`.

Run `astrona validate .` and `astrona test . --accept-terms --headless` in this
folder. `testing/verify-start.sh` checks that every outcome fails on the
starting state; after the reference solution every outcome must pass.
