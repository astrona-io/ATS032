---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Save An etcd Snapshot Before An Upgrade: Solution

Connect to the lab first. All commands below run on the node `controlplane`, as the user `student`:

```sh
astrona ssh astro-ats-032-lab-040-01-03
```

## Find the etcd settings

etcd is a static Pod: the kubelet starts it from a manifest file on the node. The command line in that manifest holds the client address and the three certificate files that a client needs. The manifest is readable only by `root`, so use `sudo`:

```sh
sudo grep -E -- '--(data-dir|listen-client-urls|trusted-ca-file|cert-file|key-file)=' /etc/kubernetes/manifests/etcd.yaml
```

The lab printed these lines:

```text
    - --cert-file=/etc/kubernetes/pki/etcd/server.crt
    - --data-dir=/var/lib/etcd
    - --key-file=/etc/kubernetes/pki/etcd/server.key
    - --listen-client-urls=https://127.0.0.1:2379,https://10.0.2.15:2379
    - --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
```

The client address `https://127.0.0.1:2379` works from the node itself. `etcdctl` uses the same CA (certificate authority) file, certificate and key as etcd to connect over TLS (Transport Layer Security). etcd checks the client certificate, so a command without these three files cannot connect.

## Create the backup directory

`etcdctl snapshot save` does not create missing directories. If you run it before the directory exists, it stops with this error:

```text
Error: could not open /var/lib/etcd/backup/pre-upgrade.db.part (open /var/lib/etcd/backup/pre-upgrade.db.part: no such file or directory)
```

Create the directory as `root`. Mode `0700` keeps other users of the node out, which matters because a snapshot holds every Secret of the cluster:

```sh
sudo mkdir -p -m 0700 /var/lib/etcd/backup
```

## Save the snapshot

Run `etcdctl` with `sudo`, because only `root` can read the private key in `/etc/kubernetes/pki/etcd/`. The endpoint is the local client address, and the three certificate options let `etcdctl` pass the client certificate check:

```sh
sudo etcdctl \
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

`etcdctl` writes the file with mode `0600`, so only `root` on the node can read it. `sudo ls -l /var/lib/etcd/backup` shows `-rw-------` for `pre-upgrade.db`.

## Check the snapshot and record the revision

`etcdutl` reads the snapshot file directly. It does not connect to etcd, so it needs no certificates, but it needs `sudo` to read the file:

```sh
sudo etcdutl snapshot status /var/lib/etcd/backup/pre-upgrade.db --write-out=table
```

A run of this lab printed this table. Your numbers differ:

```text
+----------+----------+------------+------------+---------+
|   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE | VERSION |
+----------+----------+------------+------------+---------+
| 59441459 |      531 |        328 |     942 kB |   3.6.0 |
+----------+----------+------------+------------+---------+
```

A hash, a number of keys above zero and a size above zero show a usable file. The revision is the etcd revision at the time of the snapshot. Record it, with your own value in place of `531`:

```sh
kubectl -n starfleet-032-040-01-03 create configmap snapshot-record --from-literal=revision=531
```

`kubectl` answers `configmap/snapshot-record created`. The grader runs `etcdutl snapshot status` on the same file. It checks that the revision is newer than an object that the lab created at the start, so an old snapshot does not pass, and it compares the revision with the ConfigMap.
