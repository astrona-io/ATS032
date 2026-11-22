# Save An etcd Snapshot Before An Upgrade

Author notes for the graded lab `ats-032-lab-040-01-03`. The learner reads `question.md` and, after the attempt, `solution.md`.

## Runtime

This is a QEMU lab, not a kind lab: the learner runs `etcdctl` and `etcdutl` on the control-plane host with `sudo`, as on the exam. The VM boots from `ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks` (the same image as `lab-02`). The image has no `etcdctl` or `etcdutl` on the host.

`bootstrap/setup.sh`:

- runs `/usr/local/sbin/astrona-kubeadm-init` (node `controlplane`, cluster name `astro-ats-032-lab-040-01-03`, user `student`);
- copies `etcdctl` and `etcdutl` into `/usr/local/bin` from the root file system of the running etcd container, which is the etcd image already in containerd. `ctr images mount` fails on this image's containerd 2.2 (`no such device`), so the script does not use it. Nothing is pulled;
- removes any old `/var/lib/etcd/backup` and creates the namespace `starfleet-032-040-01-03` and the ConfigMap `upgrade-ticket`. Its `resourceVersion` is an etcd revision, so a snapshot taken after the start has a revision at least as high.

## Scripts and graders

astrona pipes each script into `bash` on the VM as the `astrona` account, with no other lab file next to it. Every script is therefore self-contained:

- `validate.sh` holds the shared check logic (one function per outcome and the context guard). It is the only file to edit.
- `testing/render-graders.sh` copies that logic into `validation/validate-<outcome>.sh`, `testing/verify-start.sh` and `testing/wait-solved.sh`. Run it after every change to `validate.sh`; `--check` reports stale files.
- The context guard requires `/etc/kubernetes/admin.conf` with the context `kubernetes-admin@astro-ats-032-lab-040-01-03`.

| Outcome | Points | Passes when |
| --- | --- | --- |
| `snapshot-saved` | 1 | `etcdutl snapshot status /var/lib/etcd/backup/pre-upgrade.db` reports a hash, keys and a size above zero, and a revision at least the `resourceVersion` of ConfigMap `upgrade-ticket` |
| `snapshot-recorded` | 1 | ConfigMap `snapshot-record` in `starfleet-032-040-01-03` has `revision` equal to that revision |

Nothing in the lab stores an answer key. QEMU labs cannot join the kind exam, so the `astrona.yaml` entry has no `examScope`.

## Test

```sh
astrona validate sections/section-040/module-01/labs/lab-03 --accept-terms
astrona test sections/section-040/module-01/labs/lab-03 --accept-terms --headless
```

`testing.init` runs `testing/verify-start.sh` (every outcome fails on the start), `solution/apply.sh`, then `testing/wait-solved.sh`.
