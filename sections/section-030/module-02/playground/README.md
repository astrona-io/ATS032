# Authentication, Anonymous Access And Authorization Modes Playground

This ungraded environment is a QEMU VM (`ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks-{ARCH}`, pinned by digest in `config.yaml`) with a single-node kubeadm cluster: node `controlplane`, cluster `astro-ats-032-playground-030-02`, Kubernetes v1.35. The learner connects with `astrona ssh astro-ats-032-playground-030-02` as `student`, who has `sudo` and a working `kubectl`.

`bootstrap/setup.sh` runs `/usr/local/sbin/astrona-kubeadm-init` behind a context guard and seeds the example content inline (astrona pipes the script into `bash` on the VM with no other file next to it): namespaces `starfleet` and `outpost`, the `probe` Deployment and Service, the pods `shuttle` and `drifter`, and the ClusterRoleBindings `anonymous-viewer` and `ops-viewer`. All images come from the image cache on the node (`imagePullPolicy: IfNotPresent`), so the VM works offline. `docs/overview.md` is the guide the learner reads. The configuration has no submission, grading or testing fields.

Start it with `astrona run .` from this directory, and remove it with `astrona destroy --accept-terms`.
