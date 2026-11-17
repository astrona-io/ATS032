# Run An etcd Restore Drill From A Snapshot

Author notes for the graded lab `ats-032-lab-040-03-03`. The learner reads `question.md` and,
after the attempt, `solution.md`.

- `bootstrap/setup.sh` removes any old `/var/lib/etcd/drill` and
  `/var/lib/etcd/backup` on the control plane node, then saves a fresh snapshot
  to `/var/lib/etcd/backup/nightly.db` with `etcdctl` inside the etcd Pod.
- `testing/live.py` reads both files with `etcdutl snapshot status` inside the
  etcd Pod. `drill-restored` needs `/var/lib/etcd/drill/member/wal` and a
  database at `member/snap/db` with the same revision as the snapshot (a
  restore keeps the revision but changes the hash). `drill-recorded` compares
  the ConfigMap with the snapshot revision. Both outcomes also require the
  etcd Pod to stay Ready.
- `solution/apply.sh` runs `etcdutl snapshot restore` in the etcd Pod and
  records the revision. It is not idempotent: the restore refuses a data
  directory that is not empty.
- The lab writes on the control plane node, so its `examScope` is `cluster`.

Run `astrona validate .` and `astrona test . --accept-terms --headless` in this
folder. `testing/verify-start.sh` checks that every outcome fails on the
starting state; after the reference solution every outcome must pass.
