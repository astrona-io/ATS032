---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Save An etcd Snapshot Before An Upgrade

Allow about 8 minutes for the tasks.

The `starfleet` cluster gets a Kubernetes upgrade tonight. The change ticket asks for an etcd snapshot before the first `kubeadm` command runs, and for proof that the snapshot can be read.

## Connect to the lab

Use a shell on your own machine. The kubeconfig file holds the address and the credentials of this lab's cluster, and `kubectl` uses it.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-040-01-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-040-01-03" || exit 1
node_name="astro-ats-032-lab-040-01-03-control-plane"
```

The node of a `kind` cluster is a container on your machine. Run a command inside it with `podman exec "$node_name" <command>`. If your machine uses Docker, write `docker exec` instead.

## Tasks

etcd runs as the static Pod `etcd-astro-ats-032-lab-040-01-03-control-plane` in the namespace `kube-system`. Its image contains `etcdctl` and `etcdutl`, and the Pod mounts the node directory `/var/lib/etcd` at the same path. The client certificates are in `/etc/kubernetes/pki/etcd/` inside the Pod.

1. Save an etcd snapshot to `/var/lib/etcd/backup/pre-upgrade.db` on the control plane node. The directory `/var/lib/etcd/backup` does not exist yet. The snapshot must be taken after the lab started.
2. Read the snapshot with `etcdutl snapshot status`. Create the ConfigMap `snapshot-record` in the namespace `starfleet-032-040-01-03` with the key `revision` set to the revision that the command reports for the file.

Do not stop etcd and do not change its manifest.
