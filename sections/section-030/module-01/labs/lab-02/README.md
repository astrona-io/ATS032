# Harden The Kubelet On A Node

Author notes for lab `ats-032-lab-030-01-02`. The learner reads `question.md` and `solution.md`.

## Runtime

This is a QEMU lab, not a kind lab: the task edits the kubelet configuration file and restarts the `kubelet` systemd service on a real host. The VM boots from `ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks`. It is a single kubeadm node called `controlplane`; there is no worker node.

`vm/install.sh` runs `/usr/local/sbin/astrona-kubeadm-init` (node `controlplane`, cluster name `astro-ats-032-lab-030-01-02`, admin kubeconfig also for `student`), then runs `bootstrap/setup.sh`, which opens the kubelet API in `/var/lib/kubelet/config.yaml`: `anonymous.enabled: true`, `authorization.mode: AlwaysAllow` and `readOnlyPort: 10255`. It restarts the kubelet, waits until `/configz` reports `AlwaysAllow`, and starts the Pod `probe` (`busybox:1.37.0`, already in containerd) in `starfleet-032-030-01-02`. The lab needs no network.

## Scripts and graders

The lab uses the shared qemu layout. `vm/` holds the scripts astrona pipes into the VM; `scripts/ci/vm-lab.py` generates them from the lab files, so regenerate them with `python3 scripts/ci/vm-lab.py sections/section-030/module-01/labs/lab-02` after you change a lab file (`--check` reports stale files). `vm/install.sh` builds the cluster, writes the lab files to `/opt/astrona-lab` and runs `bootstrap/setup.sh` there; the other `vm/` scripts run their copy in `/opt/astrona-lab`.

- `testing/check.py`, `testing/verify-start.sh`, `testing/wait-solved.sh`, `validation/validate-<outcome>.sh` and `bootstrap/helpers.sh` are the shared files from `scripts/ci/lab-files`; do not edit them per lab.
- `testing/live.py` holds the checks of this lab, one `if wants('<outcome>'):` block per outcome. `testing/requirements.json` holds the guard: the context, the namespace and an API server `/readyz` check.
- Every script refuses to run unless `kubectl config current-context` is `${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-032-lab-030-01-02}`. The node is named `controlplane`, as on an exam cluster.

| Outcome | Points | Passes when |
| --- | --- | --- |
| `kubelet-config-hardened` | 1 | `/configz` of node `controlplane` reports `anonymous.enabled: false`, `webhook.enabled: true`, `authorization.mode: Webhook` and no read-only port |
| `kubelet-anon-rejected` | 1 | `curl -sk https://<InternalIP>:10250/pods` returns `401`, and `curl http://<InternalIP>:10255/pods` exits with code 7 (connection refused) |
| `node-ready` | 1 | node `controlplane` is Ready with the hardened configuration, Pod `probe` runs on it, and `kubectl logs probe` prints `probe started` |

## Test

```sh
astrona validate sections/section-030/module-01/labs/lab-02 --accept-terms
astrona test sections/section-030/module-01/labs/lab-02 --accept-terms --headless
```

`testing.init` runs `vm/verify-start.sh` (every outcome fails on the start), `vm/apply-solution.sh` (the copy of `solution/apply.sh`), then `vm/wait-solved.sh`.
