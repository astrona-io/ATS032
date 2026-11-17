---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Save An etcd Snapshot Before An Upgrade: Solution

Connect to the lab first, so that `kubectl` talks to this lab's cluster and `$node_name` names its control plane node. The variable `$etcd_pod` holds the name of the etcd Pod:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-040-01-03)"
node_name="astro-ats-032-lab-040-01-03-control-plane"
etcd_pod="etcd-$node_name"
```

## Find the etcd settings

etcd is a static Pod: the kubelet starts it from a manifest file on the node. Its command line holds the client address and the three certificate files that a client needs. Print it one flag per line:

```sh
kubectl -n kube-system get pod "$etcd_pod" -o jsonpath='{range .spec.containers[0].command[*]}{@}{"\n"}{end}'
```

Look for `--listen-client-urls` (it includes `https://127.0.0.1:2379`), `--trusted-ca-file`, `--cert-file`, `--key-file` and `--data-dir=/var/lib/etcd`. `etcdctl` uses the same CA (certificate authority) file, certificate and key to connect over TLS (Transport Layer Security).

## Create the backup directory

`etcdctl snapshot save` does not create missing directories. Without the directory it stops with this error:

```text
Error: could not open /var/lib/etcd/backup/pre-upgrade.db.part (open /var/lib/etcd/backup/pre-upgrade.db.part: no such file or directory)
```

The etcd image has no shell and no `mkdir`, so create the directory on the node. The etcd Pod sees it at the same path, because it mounts `/var/lib/etcd` from the node. Mode `0700` keeps other users of the node out, which matters because a snapshot holds every Secret of the cluster:

```sh
podman exec "$node_name" install -d -m 0700 /var/lib/etcd/backup
```

## Save the snapshot

Run `etcdctl` inside the etcd Pod. The endpoint is the local client address, and the three certificate options let `etcdctl` pass the client certificate check:

```sh
kubectl -n kube-system exec "$etcd_pod" -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /var/lib/etcd/backup/pre-upgrade.db
```

`etcdctl` prints a few log lines in JSON and ends with these two lines:

```text
Snapshot saved at /var/lib/etcd/backup/pre-upgrade.db
Server version 3.6.0
```

`etcdctl` writes the file with mode `0600`, so only `root` on the node can read it.

## Check the snapshot and record the revision

`etcdutl` reads the snapshot file directly. It does not connect to etcd, so it needs no certificates:

```sh
kubectl -n kube-system exec "$etcd_pod" -- etcdutl snapshot status /var/lib/etcd/backup/pre-upgrade.db --write-out=table
```

A run of this lab printed this table. Your numbers differ:

```text
+----------+----------+------------+------------+---------+
|   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE | VERSION |
+----------+----------+------------+------------+---------+
| 629f456e |      544 |        365 |     1.2 MB |   3.6.0 |
+----------+----------+------------+------------+---------+
```

A hash, a number of keys above zero and a size above zero show a usable file. The revision is the etcd revision at the time of the snapshot. Record it, with your own value in place of `544`:

```sh
kubectl -n starfleet-032-040-01-03 create configmap snapshot-record --from-literal=revision=544
```

The grader runs `etcdutl snapshot status` on the same file. It checks that the revision is newer than an object that the lab created at the start, so an old snapshot does not pass, and it compares the revision with the ConfigMap.
