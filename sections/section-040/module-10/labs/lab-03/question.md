---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Save An etcd Snapshot Before An Upgrade

Allow about 8 minutes for the tasks.

The `starfleet` cluster gets a Kubernetes upgrade tonight. The change ticket asks for an etcd snapshot before the first `kubeadm` command runs, and for proof that the snapshot can be read.

## Connect to the lab

The lab is a virtual machine (VM) with one Kubernetes node. Open a shell on it from your own machine:

```sh
astrona ssh astro-ats-032-lab-040-01-03
```

You are the user `student`. You can run commands as root with `sudo`, and `kubectl` already works for this cluster. The node is called `controlplane`, and it is the only node.

## Tasks

etcd runs as the static Pod `etcd-controlplane` in the namespace `kube-system`. The kubelet starts it from the manifest `/etc/kubernetes/manifests/etcd.yaml`. Its data directory is `/var/lib/etcd` on the node, and its client certificates are in `/etc/kubernetes/pki/etcd/`. The etcd clients `etcdctl` and `etcdutl` are installed on the node in `/usr/local/bin`.

1. Save an etcd snapshot to `/var/lib/etcd/backup/pre-upgrade.db` on the node `controlplane`. The directory `/var/lib/etcd/backup` does not exist yet. The snapshot must be taken after the lab started.
2. Read the snapshot with `etcdutl snapshot status`. Create the ConfigMap `snapshot-record` in the namespace `starfleet-032-040-01-03` with the key `revision` set to the revision that the command reports for the file.

Do not stop etcd and do not change its manifest.

## How the answer is checked

The grader runs two checks:

- `etcdutl snapshot status` reads `/var/lib/etcd/backup/pre-upgrade.db` as a snapshot with a hash, keys and a size above zero, and its revision is newer than an object that the lab created at the start.
- The ConfigMap `snapshot-record` has the key `revision` with the same revision that `etcdutl snapshot status` reports for that file.
