# Restart The Container Runtime On A Drained Node

Author notes for lab `ats-032-lab-040-03-02`. The learner reads `question.md` and `solution.md`.

## Runtime

This is a QEMU lab, not a kind lab: restarting `containerd` with `systemctl` needs a real host. The VM boots from `ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks-{ARCH}`, pinned by the disk digests in `config.yaml`. `bootstrap/setup.sh` runs `/usr/local/sbin/astrona-kubeadm-init` to create a single-node cluster (node `controlplane`, cluster name `astro-ats-032-lab-040-03-02`). The lab needs no network: the `probe` Pods use `busybox:1.37.0`, which the image already holds.

Start state: the Deployment `probe` (two replicas) runs on `controlplane`, and the node is cordoned but not drained. The ConfigMap `maintenance-baseline` in `starfleet-032-040-03-02` records the `InvocationID` of the `containerd` service and the UIDs of the `probe` Pods. The `InvocationID` changes on every start of the unit, also after a reboot, so the check does not depend on the monotonic clock.

There is no PodDisruptionBudget: with one node, a budget with `maxUnavailable: 1` would block the drain forever, because the first replacement Pod can never become Ready on the cordoned node. `solution.md` explains this.

## Scripts and graders

astrona pipes each script into `bash` on the VM as the `astrona` account, with no other lab file next to it. Every script is therefore self-contained:

- `validate.sh` holds the shared check logic (one function per outcome and the context guard). It is the only file to edit.
- `testing/render-graders.sh` copies that logic into `validation/validate-<outcome>.sh`, `testing/verify-start.sh` and `testing/wait-solved.sh`. Run it after every change to `validate.sh`; `--check` reports stale files.
- The context guard requires `/etc/kubernetes/admin.conf` with the context `kubernetes-admin@astro-ats-032-lab-040-03-02`.

Outcomes:

| Outcome | Points | Passes when |
| --- | --- | --- |
| `runtime-restarted` | 1 | `containerd` is `active` and its `InvocationID` differs from the baseline |
| `probe-pods-replaced` | 1 | no `probe` Pod UID from the baseline remains, and Deployment `probe` has two available replicas |
| `node-in-service` | 1 | node `controlplane` is Ready and not cordoned |

`solution/apply.sh` drains the node, restarts `containerd`, waits for Ready and uncordons. It can run again on a solved lab.

## Test

```sh
astrona validate sections/section-040/module-03/labs/lab-02 --accept-terms
astrona test sections/section-040/module-03/labs/lab-02 --accept-terms --headless
```

`testing.init` runs `testing/verify-start.sh` (every outcome fails on the start), `solution/apply.sh`, then `testing/wait-solved.sh`.
