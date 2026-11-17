---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Run An etcd Restore Drill From A Snapshot: Solution

Connect to the lab first, so that `kubectl` talks to this lab's cluster:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-040-03-03)"
node_name="astro-ats-032-lab-040-03-03-control-plane"
etcd_pod="etcd-astro-ats-032-lab-040-03-03-control-plane"
```

The output below comes from one run of this lab. The hash, the revision and the times differ in your run.

## Read the snapshot

`etcdutl` works on files and does not need a connection to a running etcd. Run it inside the etcd Pod, because the node itself has no `etcdutl`:

```sh
kubectl -n kube-system exec "$etcd_pod" -- etcdutl snapshot status /var/lib/etcd/backup/nightly.db --write-out=table
```

```text
+---------+----------+------------+------------+---------+
|  HASH   | REVISION | TOTAL KEYS | TOTAL SIZE | VERSION |
+---------+----------+------------+------------+---------+
| 786b5b8 |      503 |        363 |     1.1 MB |   3.6.0 |
+---------+----------+------------+------------+---------+
```

The revision is the counter of the etcd key-value store at the time of the snapshot. Note it: in this run it is `503`.

## Restore into a separate data directory

`etcdutl snapshot restore` writes a new data directory from the snapshot. It does not change the running etcd, because the live data stays in `/var/lib/etcd/member` and the drill writes to `/var/lib/etcd/drill`:

```sh
kubectl -n kube-system exec "$etcd_pod" -- etcdutl snapshot restore /var/lib/etcd/backup/nightly.db --data-dir /var/lib/etcd/drill
```

The command logs each step. The first and the last line of this run were (the lines between them are left out):

```text
2026-11-17T21:46:47Z	info	snapshot/v3_snapshot.go:305	restoring snapshot	{"path": "/var/lib/etcd/backup/nightly.db", "wal-dir": "/var/lib/etcd/drill/member/wal", "data-dir": "/var/lib/etcd/drill", "snap-dir": "/var/lib/etcd/drill/member/snap", "initial-memory-map-size": 10737418240}
2026-11-17T21:46:47Z	info	snapshot/v3_snapshot.go:333	restored snapshot	{"path": "/var/lib/etcd/backup/nightly.db", "wal-dir": "/var/lib/etcd/drill/member/wal", "data-dir": "/var/lib/etcd/drill", "snap-dir": "/var/lib/etcd/drill/member/snap", "initial-memory-map-size": 10737418240}
```

The restore refuses a directory that already has content. A second run of the same command printed:

```text
Error: data-dir "/var/lib/etcd/drill" not empty or could not be read
```

## Check the restored data

A data directory has a `member` folder with a write-ahead log (`wal`) and the database (`snap/db`):

```sh
podman exec "$node_name" ls -l /var/lib/etcd/drill/member
kubectl -n kube-system exec "$etcd_pod" -- etcdutl snapshot status /var/lib/etcd/drill/member/snap/db --write-out=table
```

```text
total 0
drwx------. 2 root root 62 Nov 17 21:46 snap
drwx------. 2 root root 51 Nov 17 21:46 wal
+----------+----------+------------+------------+---------+
|   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE | VERSION |
+----------+----------+------------+------------+---------+
| 4bf50c27 |      503 |        363 |     1.1 MB |   3.6.0 |
+----------+----------+------------+------------+---------+
```

The revision and the number of keys match the snapshot. The hash differs, because the restore removes the old membership information and writes new cluster membership into the database. Compare revisions and key counts, not hashes, when you check a restore.

## Record the result

Save this as `configmap-restore-drill.yaml`, with your own revision:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: restore-drill
  namespace: starfleet-032-040-03-03
data:
  revision: "503"
```

Apply it:

```sh
kubectl apply -f configmap-restore-drill.yaml
```

The live etcd Pod was never stopped:

```sh
kubectl -n kube-system get pods -l component=etcd
```

```text
NAME                                             READY   STATUS    RESTARTS   AGE
etcd-astro-ats-032-lab-040-03-03-control-plane   1/1     Running   0          28s
```

In a real restore you would now point the `etcd-data` volume in `/etc/kubernetes/manifests/etcd.yaml` at the restored directory. The drill stops before that step, because it only has to prove that the snapshot can be restored.
