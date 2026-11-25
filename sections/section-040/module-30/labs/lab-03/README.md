# Restore etcd From A Snapshot

Author notes for lab `ats-032-lab-040-03-03`. The learner reads `question.md` and `solution.md`.

## Runtime

This is a QEMU lab, not a kind lab: the student edits the etcd static Pod manifest on a real kubeadm host. The VM boots from `ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks`. `vm/install.sh` runs `/usr/local/sbin/astrona-kubeadm-init` to create a single-node cluster (node `controlplane`, cluster name `astro-ats-032-lab-040-03-03`) and then runs `bootstrap/setup.sh`. The lab needs no network.

The image has no `etcdctl` or `etcdutl` on the host. The bootstrap exports the etcd image that containerd already holds (`ctr images export --local`), unpacks the layers and installs both binaries to `/usr/local/bin`. `ctr images mount` does not work on containerd 2.2.1 in this image ("no such device").

Start state:

- The ConfigMap `fleet-roster` is created in `starfleet-032-040-03-03`.
- `etcdctl snapshot save` writes `/var/backups/etcd/nightly.db` (root only).
- The UID of `fleet-roster` goes to `/etc/astrona-lab/etcd-restore.env` (root only). It lives on the host because the restore rolls the cluster back.
- `fleet-roster` is deleted and the ConfigMap `course-correction` is created.

## Scripts and graders

The lab uses the shared qemu layout. `vm/` holds the scripts astrona pipes into the VM; `scripts/ci/vm-lab.py` generates them from the lab files, so regenerate them with `python3 scripts/ci/vm-lab.py sections/section-040/module-30/labs/lab-03` after you change a lab file (`--check` reports stale files). `vm/install.sh` builds the cluster, writes the lab files to `/opt/astrona-lab` and runs `bootstrap/setup.sh` there; the other `vm/` scripts run their copy in `/opt/astrona-lab`.

- `testing/check.py`, `testing/verify-start.sh`, `testing/wait-solved.sh`, `validation/validate-<outcome>.sh` and `bootstrap/helpers.sh` are the shared files from `scripts/ci/lab-files`; do not edit them per lab.
- `testing/live.py` holds the checks of this lab, one `if wants('<outcome>'):` block per outcome. `testing/requirements.json` holds the guard: the context, the namespace and an API server `/readyz` check.
- Every script refuses to run unless `kubectl config current-context` is `${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-032-lab-040-03-03}`. The node is named `controlplane`, as on an exam cluster.

Outcomes:

| Outcome | Points | Passes when |
| --- | --- | --- |
| `etcd-on-restored-data` | 1 | the host directory that the manifest mounts at `--data-dir` is not `/var/lib/etcd`, holds `member/snap/db`, and `etcdctl endpoint health` passes |
| `roster-restored` | 1 | ConfigMap `fleet-roster` exists with the UID from the baseline file |
| `later-change-gone` | 1 | ConfigMap `course-correction` returns NotFound |

The grader accepts any restore directory and either way of wiring it (a changed `hostPath`, or a new volume with a matching `--data-dir`).

`solution/apply.sh` restores into `/var/lib/etcd-restore` with `--bump-revision 1000000000 --mark-compacted`, changes the `etcd-data` hostPath and waits for etcd and `/readyz`. It skips the restore and the edit when they are already done, so it can run again.

## Test

```sh
astrona validate sections/section-040/module-30/labs/lab-03 --accept-terms
astrona test sections/section-040/module-30/labs/lab-03 --accept-terms --headless
```

`testing.init` runs `vm/verify-start.sh` (every outcome fails on the start), `vm/apply-solution.sh` (the copy of `solution/apply.sh`), then `vm/wait-solved.sh`.
