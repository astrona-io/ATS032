---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Snapshot And Verify

An upgrade can fail in a way that damages cluster state. The etcd datastore holds all of that state: every object, every Secret, every Role. A snapshot of etcd taken before the upgrade lets you return to a known state. After the upgrade, a short set of checks proves that the cluster works. This part runs both on the playground, which is now at Kubernetes 1.36.

In a real upgrade, the snapshot comes before the first `kubeadm` command. The commands are the same before and after an upgrade, so you can practise them now on the upgraded cluster.

## Find the etcd settings

In a kubeadm cluster, etcd runs as a static Pod on the control-plane node, and its command line holds every setting a client needs. Open a shell with `astrona ssh astro-ats-032-playground-040-01`. This command prints one flag per line:

<!-- astrona:playground:renew -->

```sh
kubectl -n kube-system get pod -l component=etcd -o jsonpath='{range .items[0].spec.containers[0].command[*]}{@}{"\n"}{end}'
```

The output has 20 lines. These are the lines that matter for a snapshot:

```text
--cert-file=/etc/kubernetes/pki/etcd/server.crt
--client-cert-auth=true
--data-dir=/var/lib/etcd
--key-file=/etc/kubernetes/pki/etcd/server.key
--listen-client-urls=https://127.0.0.1:2379,https://10.0.2.15:2379
--trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
```

`--data-dir` is the directory with the database. `--listen-client-urls` includes `https://127.0.0.1:2379`, the client address on the node itself. `--client-cert-auth=true` means that etcd accepts only clients with a certificate signed by its CA (certificate authority). The client therefore needs three files: the CA file from `--trusted-ca-file`, and a certificate and key, here the server's own pair from `--cert-file` and `--key-file`.

## Take a snapshot

The client for a running etcd is `etcdctl`. It is part of the etcd container image, and on the playground it is also installed on the host. Check its version:

```sh
etcdctl version
```

```text
etcdctl version: 3.6.6
API version: 3.6
```

`etcdctl` 3.6 speaks only version 3 of the etcd API. Older guides set `ETCDCTL_API=3`. With 3.6, that variable has no effect, and `etcdctl` prints a warning `"unrecognized environment variable"` for it. Run the snapshot as root, because only root can read the key file. The endpoint is the local client address:

```sh
sudo etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /var/backups/etcd-snapshot.db
```

`etcdctl` prints a few log lines in JSON and ends with these two lines:

```text
Snapshot saved at /var/backups/etcd-snapshot.db
Server version 3.6.0
```

`etcdctl` asked the etcd server for a copy of its database over TLS (Transport Layer Security) and wrote it to the file. Now check the file. The tool for files is `etcdutl`. It reads the file directly and needs no running etcd and no certificates. In etcd 3.6, `etcdctl snapshot status` no longer exists: it only prints the help text of the `snapshot` command.

```sh
sudo ls -l /var/backups/etcd-snapshot.db
sudo etcdutl snapshot status /var/backups/etcd-snapshot.db --write-out=table
```

```text
-rw------- 1 root root 3489824 Nov 18 08:57 /var/backups/etcd-snapshot.db
+----------+----------+------------+------------+---------+
|   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE | VERSION |
+----------+----------+------------+------------+---------+
| 935f4d5e |     1568 |        513 |     3.5 MB |   3.6.0 |
+----------+----------+------------+------------+---------+
```

The table shows the hash, the etcd revision at the time of the snapshot, the number of keys and the size. A file with a size of zero or a missing hash is not a usable snapshot. Your numbers differ.

A snapshot contains every Secret, and etcd stores Secrets in plain form unless encryption at rest is configured. Treat the file like a credential. `etcdctl` already gave it mode `0600`, so only root can read it. Copy it to a protected place off the host, and delete old copies that you do not need.

## Restore

A restore is a recovery action, not part of a normal upgrade. `etcdutl snapshot restore` writes a new data directory from the snapshot. It does not touch the running etcd:

```sh
sudo etcdutl snapshot restore /var/backups/etcd-snapshot.db --data-dir /var/lib/etcd-restored
```

The command prints log lines with tabs between the fields. The output is shortened to the last line:

```text
2026-11-18T08:57:28Z	info	snapshot/v3_snapshot.go:333	restored snapshot	{"path": "/var/backups/etcd-snapshot.db", "wal-dir": "/var/lib/etcd-restored/member/wal", "data-dir": "/var/lib/etcd-restored", "snap-dir": "/var/lib/etcd-restored/member/snap", "initial-memory-map-size": 10737418240}
```

`/var/lib/etcd-restored` now holds a `member` directory, like `/var/lib/etcd`. To use it, you would edit `/etc/kubernetes/manifests/etcd.yaml` so that the `hostPath` of the volume named `etcd-data` is `/var/lib/etcd-restored`. The kubelet then recreates the etcd Pod with the restored data. Do not do that on the playground now, because it would return the cluster to the time of the snapshot. Remove the copy with `sudo rm -rf /var/lib/etcd-restored`.

A snapshot covers only the cluster state in etcd. Data in application databases and in volumes is not part of it and needs its own backup. With several control-plane nodes, the restore has more steps, because every etcd member must start from the same snapshot.

## Verify after the upgrade

After the last node is done, check the cluster from top to bottom. The first command lists the nodes and their versions. The second asks the API server for the result of its own health checks, one line for each check. The third lists Pods in any namespace that are not running:

```sh
kubectl get nodes
kubectl get --raw='/readyz?verbose'
kubectl get pods -A --field-selector=status.phase!=Running
```

The `readyz` output has 37 check lines. It is shortened here to the first three and the last two lines:

```text
NAME           STATUS   ROLES           AGE     VERSION
controlplane   Ready    control-plane   8m44s   v1.36.6
[+]ping ok
[+]log ok
[+]etcd ok
...
[+]shutdown ok
readyz check passed
No resources found
```

The node is `Ready` at the target version, every health check shows `ok`, and no Pod is outside the `Running` phase. On a busy cluster, the third command can also show finished Jobs, but nothing in a failed or pending state. kubeadm renewed the certificates during the upgrade, and you can read their dates on the control-plane host:

```sh
sudo kubeadm certs check-expiration
```

The output is shortened to a few rows:

```text
CERTIFICATE                EXPIRES                  RESIDUAL TIME   CERTIFICATE AUTHORITY   EXTERNALLY MANAGED
admin.conf                 Nov 18, 2027 08:51 UTC   364d            ca                      no
apiserver                  Nov 18, 2027 08:51 UTC   364d            ca                      no
...
CERTIFICATE AUTHORITY   EXPIRES                  RESIDUAL TIME   EXTERNALLY MANAGED
ca                      Nov 15, 2036 08:48 UTC   9y              no
```

The certificates run for one more year from the day of the upgrade. kubeadm does not renew the CAs, which expire in 2036 on the playground. Last, test the application and not only the platform. Send a request from the node to the ClusterIP of the `probe` Service:

```sh
curl -s "http://$(kubectl -n starfleet get service probe -o jsonpath='{.spec.clusterIP}')/"
```

```text
version=v1 host=probe-7db6ffd7d6-hwhxt greeting=hello
```

A `probe` Pod answered through the Service, so the Service and its endpoints work on the new version. If a node shows `NotReady` after an upgrade, read the kubelet log on that node with `sudo journalctl -u kubelet`. If the API server does not answer, list the containers with `sudo crictl ps -a` and read the log of the failing one.

You can now protect an upgrade with a snapshot, recover the state from it, and prove the result. That completes the cycle: know the versions, move the workloads, upgrade the components, and verify.

## Common pitfalls

> [!WARNING]
> - **Taking the snapshot without the three certificate options.** `etcdctl` cannot connect to the TLS endpoint.
> - **Running `etcdctl` without `sudo`.** Only root can read the key file under `/etc/kubernetes/pki/etcd/`.
> - **Using `etcdctl snapshot status` with etcd 3.6.** The command no longer exists. Use `etcdutl snapshot status`.
> - **Not checking the snapshot.** Run `etcdutl snapshot status` and read the table.
> - **Leaving a snapshot readable by everyone.** It holds all Secrets. Keep mode `0600` and store it off the host.
> - **Restoring and expecting recent changes to exist.** A restore returns to the time of the snapshot.
> - **Checking only `kubectl get nodes`.** Also check the API health, system Pods and one real application request.
