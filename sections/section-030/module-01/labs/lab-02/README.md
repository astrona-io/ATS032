# Harden The Kubelet On A Node

Author notes for lab `ats-032-lab-030-01-02`. The learner reads `question.md` and `solution.md`.

## Runtime

This is a QEMU lab, not a kind lab: the task edits the kubelet configuration file and restarts the `kubelet` systemd service on a real host. The VM boots from `ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks`. It is a single kubeadm node called `controlplane`; there is no worker node.

`bootstrap/setup.sh` runs `/usr/local/sbin/astrona-kubeadm-init` (cluster name `astro-ats-032-lab-030-01-02`, admin kubeconfig also for `student`), then opens the kubelet API in `/var/lib/kubelet/config.yaml`: `anonymous.enabled: true`, `authorization.mode: AlwaysAllow` and `readOnlyPort: 10255`. It restarts the kubelet, waits until `/configz` reports `AlwaysAllow`, and starts the Pod `probe` (`busybox:1.37.0`, already in containerd) in `starfleet-032-030-01-02`. The lab needs no network.

## Scripts and graders

astrona pipes each script into `bash` on the VM as the `astrona` account, with no other lab file next to it. Every script is therefore self-contained:

- `validate.sh` holds the shared check logic (one function per outcome and the context guard). It is the only file to edit.
- `testing/render-graders.sh` copies that logic into `validation/validate-<outcome>.sh`, `testing/verify-start.sh` and `testing/wait-solved.sh`. Run it after every change to `validate.sh`; `--check` reports stale files.
- The context guard requires `/etc/kubernetes/admin.conf` with the context `kubernetes-admin@astro-ats-032-lab-030-01-02`.

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

`testing.init` runs `testing/verify-start.sh` (every outcome fails on the start), `solution/apply.sh`, then `testing/wait-solved.sh`.
