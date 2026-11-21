# Restore etcd From A Snapshot

Author notes for lab `ats-032-lab-040-03-03`. The learner reads `question.md` and `solution.md`.

## Runtime

This is a QEMU lab, not a kind lab: the student edits the etcd static Pod manifest on a real kubeadm host. The VM boots from `ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks`. `bootstrap/setup.sh` runs `/usr/local/sbin/astrona-kubeadm-init` to create a single-node cluster (node `controlplane`, cluster name `astro-ats-032-lab-040-03-03`). The lab needs no network.

The image has no `etcdctl` or `etcdutl` on the host. The bootstrap exports the etcd image that containerd already holds (`ctr images export --local`), unpacks the layers and installs both binaries to `/usr/local/bin`. `ctr images mount` does not work on containerd 2.2.1 in this image ("no such device").

Start state:

- The ConfigMap `fleet-roster` is created in `starfleet-032-040-03-03`.
- `etcdctl snapshot save` writes `/var/backups/etcd/nightly.db` (root only).
- The UID of `fleet-roster` goes to `/etc/astrona-lab/etcd-restore.env` (root only). It lives on the host because the restore rolls the cluster back.
- `fleet-roster` is deleted and the ConfigMap `course-correction` is created.

## Scripts and graders

astrona pipes each script into `bash` on the VM as the `astrona` account, with no other lab file next to it. Every script is therefore self-contained:

- `validate.sh` holds the shared check logic (one function per outcome and the context guard). It is the only file to edit.
- `testing/render-graders.sh` copies that logic into `validation/validate-<outcome>.sh`, `testing/verify-start.sh` and `testing/wait-solved.sh`. Run it after every change to `validate.sh`; `--check` reports stale files.
- The context guard requires `/etc/kubernetes/admin.conf` with the context `kubernetes-admin@astro-ats-032-lab-040-03-03`.

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
astrona validate sections/section-040/module-03/labs/lab-03 --accept-terms
astrona test sections/section-040/module-03/labs/lab-03 --accept-terms --headless
```

`testing.init` runs `testing/verify-start.sh` (every outcome fails on the start), `solution/apply.sh`, then `testing/wait-solved.sh`.
