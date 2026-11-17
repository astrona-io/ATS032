# Save An etcd Snapshot Before An Upgrade

Author notes for the graded lab `ats-032-lab-040-01-03`. The learner reads `question.md` and,
after the attempt, `solution.md`.

- `bootstrap/setup.sh` creates the namespace, removes any old
  `/var/lib/etcd/backup` on the control plane node and creates the ConfigMap
  `upgrade-ticket`. Its `resourceVersion` is an etcd revision, so a snapshot
  taken after the start has a revision at least as high.
- `testing/live.py` runs `etcdutl snapshot status` inside the etcd Pod on every
  run and compares the revision with `upgrade-ticket` and with the learner's
  ConfigMap `snapshot-record`. Nothing in the lab stores an answer key.
- `solution/apply.sh` is the reference solution that `astrona test` applies.
- The lab writes on the control plane node and runs commands in a static Pod,
  so its `examScope` is `cluster`.

Run `astrona validate .` and `astrona test . --accept-terms --headless` in this
folder. `testing/verify-start.sh` checks that every outcome fails on the
starting state; after the reference solution every outcome must pass.
