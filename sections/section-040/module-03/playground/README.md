# Post-Maintenance Verification Playground

Author notes for the ungraded playground `ats-032-playground-040-03`. It is a QEMU VM
from `ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks-{ARCH}` (pinned by the disk
digests in `config.yaml`). `bootstrap/setup.sh` runs `astrona-kubeadm-init` for a
single-node cluster (node `controlplane`, cluster `astro-ats-032-playground-040-03`,
user `student`), copies `etcdctl` and `etcdutl` out of the etcd image that containerd
already holds, and seeds the example workloads inline. Nothing is pulled, so the VM
works offline. The learner guide is `docs/overview.md`.

The playground has no grader, no reference solution and no submission fields.
The graded tasks for this module are separate labs under `../labs/`.
Start it with `astrona run .` in this folder, connect with
`astrona ssh astro-ats-032-playground-040-03`, and remove it with
`astrona destroy --accept-terms` in this folder.
