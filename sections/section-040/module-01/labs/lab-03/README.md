# Save An etcd Snapshot Before An Upgrade

Author notes for the graded lab `ats-032-lab-040-01-03`. The learner reads `question.md` and, after the attempt, `solution.md`.

## Runtime

This is a QEMU lab, not a kind lab: the learner runs `etcdctl` and `etcdutl` on the control-plane host with `sudo`, as on the exam. The VM boots from `ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks` (the same image as `lab-02`). The image has no `etcdctl` or `etcdutl` on the host.

`vm/install.sh` runs `/usr/local/sbin/astrona-kubeadm-init` (node `controlplane`, cluster name `astro-ats-032-lab-040-01-03`, user `student`), then `bootstrap/setup.sh`, which:

- copies `etcdctl` and `etcdutl` into `/usr/local/bin` from the root file system of the running etcd container, which is the etcd image already in containerd. `ctr images mount` fails on this image's containerd 2.2 (`no such device`), so the script does not use it. Nothing is pulled;
- removes any old `/var/lib/etcd/backup` and creates the namespace `starfleet-032-040-01-03` and the ConfigMap `upgrade-ticket`. Its `resourceVersion` is an etcd revision, so a snapshot taken after the start has a revision at least as high.

## Scripts and graders

The lab uses the shared qemu layout. `vm/` holds the scripts astrona pipes into the VM; `scripts/ci/vm-lab.py` generates them from the lab files, so regenerate them with `python3 scripts/ci/vm-lab.py sections/section-040/module-01/labs/lab-03` after you change a lab file (`--check` reports stale files). `vm/install.sh` builds the cluster, writes the lab files to `/opt/astrona-lab` and runs `bootstrap/setup.sh` there; the other `vm/` scripts run their copy in `/opt/astrona-lab`.

- `testing/check.py`, `testing/verify-start.sh`, `testing/wait-solved.sh`, `validation/validate-<outcome>.sh` and `bootstrap/helpers.sh` are the shared files from `scripts/ci/lab-files`; do not edit them per lab.
- `testing/live.py` holds the checks of this lab, one `if wants('<outcome>'):` block per outcome. `testing/requirements.json` holds the guard: the context, the namespace and an API server `/readyz` check.
- Every script refuses to run unless `kubectl config current-context` is `${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-032-lab-040-01-03}`. The node is named `controlplane`, as on an exam cluster.

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

`testing.init` runs `vm/verify-start.sh` (every outcome fails on the start), `vm/apply-solution.sh` (the copy of `solution/apply.sh`), then `vm/wait-solved.sh`.
