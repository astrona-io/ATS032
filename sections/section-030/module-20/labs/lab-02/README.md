---
exam_objectives:
- Restrict access to Kubernetes API
---
# Remove Static Token Authentication From The API Server

Author notes for lab `ats-032-lab-030-02-02`. The learner reads `question.md` and `solution.md`.

## Runtime

This is a QEMU lab, not a kind lab: the learner edits the kube-apiserver static Pod manifest with `sudo` on a real node. The VM boots from `ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks`, built from the `cks` layer in [qcow2-base-image](https://github.com/astrona-io/qcow2-base-image/tree/main/distros/ubuntu/layers/cks). The image holds Kubernetes v1.35 and every control-plane image, so the lab needs no network.

`vm/install.sh` runs `/usr/local/sbin/astrona-kubeadm-init` (node `controlplane`, cluster `astro-ats-032-lab-030-02-02`, user `student`). Then `bootstrap/setup.sh` creates the namespace `starfleet-032-030-02-02`, writes a random `system:masters` token to `/etc/kubernetes/pki/legacy-tokens.csv`, keeps a copy in `/var/lib/ats-032-lab/legacy-token` for the grader, adds `--token-auth-file` to the manifest and waits until a request with the token gets `200` and the Pod is Ready.

## Scripts and graders

The lab uses the shared qemu layout. `vm/` holds the scripts astrona pipes into the VM; `scripts/ci/vm-lab.py` generates them from the lab files, so regenerate them with `python3 scripts/ci/vm-lab.py sections/section-030/module-20/labs/lab-02` after you change a lab file (`--check` reports stale files). `vm/install.sh` builds the cluster, writes the lab files to `/opt/astrona-lab` and runs `bootstrap/setup.sh` there; the other `vm/` scripts run their copy in `/opt/astrona-lab`.

- `testing/check.py`, `testing/verify-start.sh`, `testing/wait-solved.sh`, `validation/validate-<outcome>.sh` and `bootstrap/helpers.sh` are the shared files from `scripts/ci/lab-files`; do not edit them per lab.
- `testing/live.py` holds the checks of this lab, one `if wants('<outcome>'):` block per outcome. `testing/requirements.json` holds the guard: the context, the namespace and an API server `/readyz` check.
- Every script refuses to run unless `kubectl config current-context` is `${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-032-lab-030-02-02}`. The node is named `controlplane`, as on an exam cluster.

Outcomes:

| Outcome | Points | Passes when |
| --- | --- | --- |
| `apiserver-no-token-file` | 1 | the manifest has no `--token-auth-file` and no file under `/etc/kubernetes` holds the old token |
| `static-token-rejected` | 1 | `https://127.0.0.1:6443/api` with the old token returns `401` |
| `apiserver-ready` | 1 | Pod `kube-apiserver-controlplane` runs without the flag, is Ready, and `/readyz` is `ok` |

## Test

```sh
astrona validate sections/section-030/module-20/labs/lab-02 --accept-terms
astrona test sections/section-030/module-20/labs/lab-02 --accept-terms --headless
```

`testing.init` runs `vm/verify-start.sh` (every outcome fails on the start), `vm/apply-solution.sh` (the copy of `solution/apply.sh`), then `vm/wait-solved.sh`.
