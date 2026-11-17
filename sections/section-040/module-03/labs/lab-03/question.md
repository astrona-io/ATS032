---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Run An etcd Restore Drill From A Snapshot

Allow about 8 minutes for the tasks.

The `starfleet` team takes an etcd snapshot every night, but nobody has ever restored one. Before the next upgrade window, the team wants proof that last night's snapshot can be turned back into a working etcd data directory, without touching the live etcd.

## Connect to the lab

Use a shell on your own machine. The kubeconfig file holds the address and the credentials of this lab's cluster, and `kubectl` uses it.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-040-03-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-040-03-03" || exit 1
node_name="astro-ats-032-lab-040-03-03-control-plane"
```

The node of a `kind` cluster is a container on your machine. Run a command inside it with `podman exec "$node_name" <command>`. If your machine uses Docker, write `docker exec` instead.

## Tasks

etcd runs as the static Pod `etcd-astro-ats-032-lab-040-03-03-control-plane` in the namespace `kube-system`. Its image contains `etcdctl` and `etcdutl`, and the Pod mounts the node directory `/var/lib/etcd` at the same path. The snapshot is the file `/var/lib/etcd/backup/nightly.db` on the control plane node.

1. Restore the snapshot `/var/lib/etcd/backup/nightly.db` into the new data directory `/var/lib/etcd/drill` on the control plane node.
2. Create the ConfigMap `restore-drill` in the namespace `starfleet-032-040-03-03` with the key `revision` set to the revision that `etcdutl snapshot status` reports for `/var/lib/etcd/backup/nightly.db`.

Do not stop etcd, do not change its manifest and do not write to `/var/lib/etcd/member`.
