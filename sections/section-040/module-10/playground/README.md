# Supported Upgrade And Node Maintenance Playground

Author notes for the ungraded playground `ats-032-playground-040-01`. The learner guide is `docs/overview.md`.

It is a QEMU VM from `ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks` (the same image as the module's labs `lab-02` and `lab-03`). The image carries kubeadm, kubelet and kubectl 1.35 and an offline package repository for 1.35 and 1.36 under `/opt/kubernetes-apt`, so the course text can run a real `kubeadm upgrade` from 1.35 to 1.36.

`bootstrap/setup.sh` runs inside the VM. It:

- runs `/usr/local/sbin/astrona-kubeadm-init` (node `controlplane`, cluster name `astro-ats-032-playground-040-01`, user `student` when it exists) and checks the context `kubernetes-admin@astro-ats-032-playground-040-01`;
- copies `etcdctl` and `etcdutl` into `/usr/local/bin` from the root file system of the running etcd container. `ctr images mount` fails on the image's containerd 2.2 (`no such device`), so the script does not use it. Nothing is pulled;
- applies the starting content inline (astrona pipes the script into `bash` with no other file next to it): namespaces `starfleet` and `outpost`, ConfigMap `probe-code`, Deployment and Service `probe` (`python:3.13-alpine`), bare Pods `shuttle` and `drifter` (`busybox:1.37.0`). Both images are pre-pulled in the image and use `imagePullPolicy: IfNotPresent`.

The cluster has one node, so `kubectl drain` leaves evicted Pods `Pending` until `kubectl uncordon`. The course text teaches that behavior on purpose. The multi-node drain is practised in lab `lab-01` (kind).

The playground has no grader, no reference solution and no submission fields. Start it with `astrona run .` in this folder and remove it with `astrona destroy --accept-terms` in this folder.
