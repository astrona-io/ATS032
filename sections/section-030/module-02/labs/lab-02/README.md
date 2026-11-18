---
exam_objectives:
- Restrict access to Kubernetes API
---
# Remove Static Token Authentication From The API Server

Author notes for lab `ats-032-lab-030-02-02`. The learner reads `question.md` and `solution.md`.

## Runtime

This is a QEMU lab, not a kind lab: the learner edits the kube-apiserver static Pod manifest with `sudo` on a real node. The VM boots from `ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks`, pinned by the disk digests in `config.yaml` and built from the `cks` layer in [qcow2-base-image](https://github.com/astrona-io/qcow2-base-image/tree/main/distros/ubuntu/layers/cks). The image holds Kubernetes v1.35 and every control-plane image, so the lab needs no network.

`bootstrap/setup.sh` runs `/usr/local/sbin/astrona-kubeadm-init` (node `controlplane`, cluster `astro-ats-032-lab-030-02-02`, user `student`). It then creates the namespace `starfleet-032-030-02-02`, writes a random `system:masters` token to `/etc/kubernetes/pki/legacy-tokens.csv`, keeps a copy in `/var/lib/ats-032-lab/legacy-token` for the grader, adds `--token-auth-file` to the manifest and waits until a request with the token gets `200` and the Pod is Ready.

## Scripts and graders

astrona pipes each script into `bash` on the VM as the `astrona` account, with no other lab file next to it. Every script is therefore self-contained:

- `validate.sh` holds the shared check logic (one function per outcome and the context guard). It is the only file to edit.
- `testing/render-graders.sh` copies that logic into `validation/validate-<outcome>.sh`, `testing/verify-start.sh` and `testing/wait-solved.sh`. Run it after every change to `validate.sh`; `--check` reports stale files.
- The context guard requires `/etc/kubernetes/admin.conf` with the context `kubernetes-admin@astro-ats-032-lab-030-02-02`.

Outcomes:

| Outcome | Points | Passes when |
| --- | --- | --- |
| `apiserver-no-token-file` | 1 | the manifest has no `--token-auth-file` and no file under `/etc/kubernetes` holds the old token |
| `static-token-rejected` | 1 | `https://127.0.0.1:6443/api` with the old token returns `401` |
| `apiserver-ready` | 1 | Pod `kube-apiserver-controlplane` runs without the flag, is Ready, and `/readyz` is `ok` |

## Test

```sh
astrona validate sections/section-030/module-02/labs/lab-02 --accept-terms
astrona test sections/section-030/module-02/labs/lab-02 --accept-terms --headless
```

`testing.init` runs `testing/verify-start.sh` (every outcome fails on the start), `solution/apply.sh`, then `testing/wait-solved.sh`.
