# Upgrade A kubeadm Control Plane From v1.35 To v1.36

Author notes for lab `ats-032-lab-040-01-02`. The learner reads `question.md` and `solution.md`.

## Runtime

This is a QEMU lab, not a kind lab: `kubeadm upgrade` needs a real host with `apt`, systemd and a kubelet service. The VM boots from `ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks`, built from the `cks` layer in [qcow2-base-image](https://github.com/astrona-io/qcow2-base-image/tree/main/distros/ubuntu/layers/cks). The image already holds:

- containerd, the kernel modules and sysctls, and swap off;
- `kubeadm`, `kubelet` and `kubectl` v1.35 on hold;
- every v1.35 and v1.36 control-plane image in containerd;
- a signed offline apt repository per minor in `/opt/kubernetes-apt/v1.35/deb/` and `/opt/kubernetes-apt/v1.36/deb/`, and `/etc/apt/sources.list.d/kubernetes.list` naming the v1.35 one;
- a bridge CNI configuration that needs no images;
- `/usr/local/sbin/astrona-kubeadm-init`, which `vm/install.sh` runs to create the cluster (node `controlplane`, cluster name `astro-ats-032-lab-040-01-02`).

The lab needs no network after the image is pulled. `apt-get update` still tries the Ubuntu archive; without network that only prints warnings.

## Scripts and graders

The lab uses the shared qemu layout. `vm/` holds the scripts astrona pipes into the VM; `scripts/ci/vm-lab.py` generates them from the lab files, so regenerate them with `python3 scripts/ci/vm-lab.py sections/section-040/module-01/labs/lab-02` after you change a lab file (`--check` reports stale files). `vm/install.sh` builds the cluster, writes the lab files to `/opt/astrona-lab` and runs `bootstrap/setup.sh` there; the other `vm/` scripts run their copy in `/opt/astrona-lab`.

- `testing/check.py`, `testing/verify-start.sh`, `testing/wait-solved.sh`, `validation/validate-<outcome>.sh` and `bootstrap/helpers.sh` are the shared files from `scripts/ci/lab-files`; do not edit them per lab.
- `testing/live.py` holds the checks of this lab, one `if wants('<outcome>'):` block per outcome. `testing/requirements.json` holds the guard: the context, the namespace and an API server `/readyz` check.
- Every script refuses to run unless `kubectl config current-context` is `${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-032-lab-040-01-02}`. The node is named `controlplane`, as on an exam cluster.

Outcomes:

| Outcome | Points | Passes when |
| --- | --- | --- |
| `control-plane-upgraded` | 2 | API server reports v1.36.x; the kube-apiserver, kube-controller-manager and kube-scheduler static Pods on `controlplane` run v1.36.x images and are Ready; DaemonSet `kube-proxy` uses a v1.36.x image; ConfigMap `kubeadm-config` records `kubernetesVersion: v1.36.x` |
| `packages-held` | 1 | `kubeadm`, `kubelet` and `kubectl` are installed at 1.36.x and listed by `apt-mark showhold` |
| `node-uncordoned` | 1 | node `controlplane` reports kubelet v1.36.x, is Ready and not cordoned, and Deployment `probe` in `starfleet-032-040-01-02` has all replicas available |

Any v1.36 patch passes. The grader cannot prove that the drain happened before the kubelet restart.

## Test

```sh
astrona validate sections/section-040/module-01/labs/lab-02 --accept-terms --headless
astrona test sections/section-040/module-01/labs/lab-02 --accept-terms --headless
```

`testing.init` runs `vm/verify-start.sh` (every outcome fails on the start), `vm/apply-solution.sh` (the copy of `solution/apply.sh`), then `vm/wait-solved.sh`.
