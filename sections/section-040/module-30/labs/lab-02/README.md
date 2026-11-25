# Restart The Container Runtime On A Drained Node

Author notes for lab `ats-032-lab-040-03-02`. The learner reads `question.md` and `solution.md`.

## Runtime

This is a QEMU lab, not a kind lab: restarting `containerd` with `systemctl` needs a real host. The VM boots from `ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks`. `vm/install.sh` runs `/usr/local/sbin/astrona-kubeadm-init` to create a single-node cluster (node `controlplane`, cluster name `astro-ats-032-lab-040-03-02`) and then runs `bootstrap/setup.sh`. The lab needs no network: the `probe` Pods use `busybox:1.37.0`, which the image already holds.

Start state: the Deployment `probe` (two replicas) runs on `controlplane`, and the node is cordoned but not drained. The ConfigMap `maintenance-baseline` in `starfleet-032-040-03-02` records the `InvocationID` of the `containerd` service and the UIDs of the `probe` Pods. The `InvocationID` changes on every start of the unit, also after a reboot, so the check does not depend on the monotonic clock.

There is no PodDisruptionBudget: with one node, a budget with `maxUnavailable: 1` would block the drain forever, because the first replacement Pod can never become Ready on the cordoned node. `solution.md` explains this.

## Scripts and graders

The lab uses the shared qemu layout. `vm/` holds the scripts astrona pipes into the VM; `scripts/ci/vm-lab.py` generates them from the lab files, so regenerate them with `python3 scripts/ci/vm-lab.py sections/section-040/module-30/labs/lab-02` after you change a lab file (`--check` reports stale files). `vm/install.sh` builds the cluster, writes the lab files to `/opt/astrona-lab` and runs `bootstrap/setup.sh` there; the other `vm/` scripts run their copy in `/opt/astrona-lab`.

- `testing/check.py`, `testing/verify-start.sh`, `testing/wait-solved.sh`, `validation/validate-<outcome>.sh` and `bootstrap/helpers.sh` are the shared files from `scripts/ci/lab-files`; do not edit them per lab.
- `testing/live.py` holds the checks of this lab, one `if wants('<outcome>'):` block per outcome. `testing/requirements.json` holds the guard: the context, the namespace and an API server `/readyz` check.
- Every script refuses to run unless `kubectl config current-context` is `${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-032-lab-040-03-02}`. The node is named `controlplane`, as on an exam cluster.

Outcomes:

| Outcome | Points | Passes when |
| --- | --- | --- |
| `runtime-restarted` | 1 | `containerd` is `active` and its `InvocationID` differs from the baseline |
| `probe-pods-replaced` | 1 | no `probe` Pod UID from the baseline remains, and Deployment `probe` has two available replicas |
| `node-in-service` | 1 | node `controlplane` is Ready and not cordoned |

`solution/apply.sh` drains the node, restarts `containerd`, waits for Ready and uncordons. It can run again on a solved lab.

## Test

```sh
astrona validate sections/section-040/module-30/labs/lab-02 --accept-terms
astrona test sections/section-040/module-30/labs/lab-02 --accept-terms --headless
```

`testing.init` runs `vm/verify-start.sh` (every outcome fails on the start), `vm/apply-solution.sh` (the copy of `solution/apply.sh`), then `vm/wait-solved.sh`.
