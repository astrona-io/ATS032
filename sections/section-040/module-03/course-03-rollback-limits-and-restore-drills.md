---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Rollback Limits And Restore Drills

Sometimes an upgrade fails, or it succeeds and breaks an application. A natural wish is to go back. Kubernetes does not support that the way a package manager does. This part explains why, what you can do instead, and how to prepare a restore of etcd so that it works the first time it is needed.

## There is no downgrade

A control-plane upgrade changes more than binaries. The API server can write objects in a newer schema to etcd, and a newer version can run storage migrations. An older API server may not be able to read what the newer one wrote. For that reason Kubernetes does not support running a control plane of an older minor version against data that a newer one has used, and `kubeadm` has no downgrade command.

This leaves two ways out. The first is to **fix forward**: find the problem and repair it on the new version. It is the right choice when the cluster works and one component or application is broken. The second is to **restore** the pre-upgrade state: stop the control plane, put the old manifests and binaries back, and restore etcd from the snapshot taken before the upgrade. It is the right choice when the control plane or the data is damaged. A restore removes every change made after the snapshot.

## Decide quickly and in writing

Agree on the rule before the window. For example: if the control plane is not healthy within a set time after the upgrade, and the cause is not known, the team restores. If the control plane is healthy and only an application fails, the team fixes forward. A written rule saves the time that a stressed team would spend arguing.

`kubeadm upgrade apply` also keeps its own copy of the static Pod manifests and the etcd data directory under `/etc/kubernetes/tmp` and tries to roll back automatically if the upgrade fails halfway. That covers a failure inside the command. It does not cover a problem you find an hour later.

## Check that etcd is healthy

Before you take a snapshot and again after the upgrade, ask etcd for its health and status. In a `kubeadm` cluster, the etcd image contains `etcdctl`, so you can run it inside the etcd Pod. The Pod name is `etcd-` followed by the node name. The three certificate options are required because etcd listens on TLS with client certificates.

<!-- astrona:playground:renew -->

```sh
kubectl -n kube-system exec etcd-astro-ats-032-playground-040-03-control-plane -- etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key endpoint health
kubectl -n kube-system exec etcd-astro-ats-032-playground-040-03-control-plane -- etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key endpoint status --write-out=table
```

The first command prints whether the endpoint is healthy and how long the check took. The second prints a table with the version of etcd, the size of the database, whether this member is the leader, and the Raft term and index. In a cluster with several etcd members, add `--cluster` to see all of them. The playground has one member, so the leader is that member.

## Snapshots that you can trust

A snapshot is only useful if it exists, is recent and can be restored. Three habits make it so.

- **Take snapshots on a schedule and before every window.** A snapshot from last month loses a month of changes. A job on the control-plane host can run `etcdctl snapshot save` with a time stamp in the file name.
- **Copy them off the host.** A snapshot on the same disk is lost with that disk. A snapshot holds every Secret in the cluster, so the off-host copy needs the same protection as the Secrets: restricted access and encryption.
- **Verify each snapshot.** `etcdutl snapshot status <file>` reads the file and reports the hash, revision and size. A zero size or a missing hash means the snapshot is not usable.

## Restore drills

A restore that has never been run is a guess. Run a drill on a spare host, never on the live control plane. The drill proves the file is complete and measures how long a restore takes. This command writes a new data directory from the snapshot and changes nothing else. It is shown to read, because the playground has no snapshot file:

```sh
etcdutl snapshot restore /var/backups/etcd-before-upgrade.db --data-dir /tmp/etcd-drill
```

A real restore then points the etcd static Pod at the new data directory. With one control-plane node, you edit `/etc/kubernetes/manifests/etcd.yaml` so that the `hostPath` of the volume `etcd-data` names the restored directory. The kubelet recreates the etcd Pod. With several control-plane nodes, every etcd member must start from the same snapshot, and each restore command needs the member name and the list of initial cluster members. Practise the multi-node procedure in a test cluster, because a mistake here splits the cluster.

After a restore, check the nodes, the API health, the system Pods, the budgets and a real request. A restored cluster returns to the time of the snapshot, so objects created after it are gone, and a controller may recreate or remove things to match the restored state. Compare the application against what you expect.

You now know the limits of going back and how to prepare for them: a written decision rule, a healthy etcd, verified snapshots and a drill that has run.

## Common pitfalls

> [!WARNING]
> - **Planning to downgrade the control plane.** Kubernetes does not support it; fix forward or restore etcd.
> - **Restoring because one application broke.** A restore removes every change since the snapshot; fix forward when the control plane is healthy.
> - **Leaving the only snapshot on the control-plane disk.** Copy it off the host and protect it like a Secret.
> - **Never testing a restore.** Run a drill on a spare host before the window.
> - **Restoring only one etcd member of several.** Every member must start from the same snapshot.
