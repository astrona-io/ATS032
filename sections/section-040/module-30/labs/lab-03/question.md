---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Restore etcd From A Snapshot

Allow about 15 minutes for the tasks.

The `starfleet` cluster took its nightly etcd snapshot. After that, a bad change deleted the ConfigMap `fleet-roster` and created the ConfigMap `course-correction`. The team decides to roll the whole cluster back to the snapshot.

## Connect to the lab

The lab is a virtual machine (VM) with one Kubernetes node. Open a shell on it from your own machine:

```sh
astrona ssh astro-ats-032-lab-040-03-03
```

You are the user `student`. You can run commands as root with `sudo`, and `kubectl` already works for this cluster. The node is called `controlplane`.

etcd is the key-value database that stores every Kubernetes object. It runs as the static Pod `etcd-controlplane` in the namespace `kube-system`. The kubelet starts it from the manifest file `/etc/kubernetes/manifests/etcd.yaml`, and it keeps its data in the host directory `/var/lib/etcd`. The tools `etcdctl` (talks to a running etcd) and `etcdutl` (works on etcd files) are installed on the node. The client certificates of etcd are in `/etc/kubernetes/pki/etcd/`.

## Tasks

The snapshot is the file `/var/backups/etcd/nightly.db` on the node.

1. Restore the snapshot into the new data directory `/var/lib/etcd-restore`.
2. Change the etcd static Pod so that it uses `/var/lib/etcd-restore` as its data directory, and wait until etcd and the API server answer again.
3. Check that the ConfigMap `fleet-roster` in the namespace `starfleet-032-040-03-03` is back and that `course-correction` is gone.

Do not delete `/var/lib/etcd`, the snapshot file or the file `/etc/astrona-lab/etcd-restore.env`, and do not reboot the VM.

## How the answer is checked

The grader runs three checks:

- etcd is healthy, and its manifest mounts a restored data directory instead of `/var/lib/etcd`.
- The ConfigMap `fleet-roster` exists with the same UID it had in the snapshot. A new ConfigMap with the same name does not pass.
- The ConfigMap `course-correction` does not exist.
