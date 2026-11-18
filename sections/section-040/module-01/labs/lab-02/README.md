# Upgrade A kubeadm Control Plane From v1.35 To v1.36

Author notes for lab `ats-032-lab-040-01-02`. The learner reads `question.md` and `solution.md`.

## Runtime

This is a QEMU lab, not a kind lab: `kubeadm upgrade` needs a real host with `apt`, systemd and a kubelet service. The VM boots from `ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks-{ARCH}`, pinned by the disk digests in `config.yaml` and built from the `cks` layer in [qcow2-base-image](https://github.com/astrona-io/qcow2-base-image/tree/main/distros/ubuntu/layers/cks). The image already holds:

- containerd, the kernel modules and sysctls, and swap off;
- `kubeadm`, `kubelet` and `kubectl` v1.35 on hold;
- every v1.35 and v1.36 control-plane image in containerd;
- a signed offline apt repository per minor in `/opt/kubernetes-apt/v1.35/deb/` and `/opt/kubernetes-apt/v1.36/deb/`, and `/etc/apt/sources.list.d/kubernetes.list` naming the v1.35 one;
- a bridge CNI configuration that needs no images;
- `/usr/local/sbin/astrona-kubeadm-init`, which `bootstrap/setup.sh` runs to create the cluster (node `controlplane`, cluster name `astro-ats-032-lab-040-01-02`).

The lab needs no network after the image is pulled. `apt-get update` still tries the Ubuntu archive; without network that only prints warnings.

## Scripts and graders

astrona pipes each script into `bash` on the VM as the `astrona` account, with no other lab file next to it. Every script is therefore self-contained:

- `validate.sh` holds the shared check logic (one function per outcome and the context guard). It is the only file to edit.
- `testing/render-graders.sh` copies that logic into `validation/validate-<outcome>.sh`, `testing/verify-start.sh` and `testing/wait-solved.sh`. Run it after every change to `validate.sh`; `--check` reports stale files.
- The context guard requires `/etc/kubernetes/admin.conf` with the context `kubernetes-admin@astro-ats-032-lab-040-01-02`. It does not read `ASTRONA_KUBE_CONTEXT`, because that variable names a kind context on the host and does not reach the VM.

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

`testing.init` runs `testing/verify-start.sh` (every outcome fails on the start), `solution/apply.sh`, then `testing/wait-solved.sh`.
