# API Server Security Boundaries Playground

This ungraded environment is a QEMU virtual machine with a single kubeadm node, `controlplane`, built from the pinned CKS image. `bootstrap/setup.sh` creates the cluster (`astro-ats-032-playground-030-01`) and the example workloads, which are inlined in the script because astrona copies only that one file into the VM. `docs/overview.md` is the guide the learner reads. The configuration has no submission, grading or testing fields.

Start it with `astrona run .` from this directory and connect with `astrona ssh astro-ats-032-playground-030-01`. The learner is `student`, with `sudo` and a working `kubectl`.

`scripts/ci/test-playground.sh` reads a kind kubeconfig and does not cover this QEMU playground.
