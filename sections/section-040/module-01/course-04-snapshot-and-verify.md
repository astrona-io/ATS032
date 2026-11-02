---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Snapshot And Verify

An upgrade can fail in a way that damages cluster state. The etcd datastore holds all of that state: every object, every Secret, every Role. A snapshot taken before the upgrade lets you return to a known state. After the upgrade, a short set of checks proves that the cluster works. The snapshot commands run on a kubeadm control-plane host and are shown to read. The checks at the end run against the playground.

## Find the etcd settings

In a kubeadm cluster, etcd runs as a static Pod on the control-plane node. You can read its flags with `kubectl`. This command prints one flag per line:

<!-- astrona:playground:renew -->

```sh
kubectl -n kube-system get pod -l component=etcd -o jsonpath='{range .items[0].spec.containers[0].command[*]}{@}{"\n"}{end}'
```

Find four values in the output: `--data-dir`, which is the directory with the database, usually `/var/lib/etcd`; `--listen-client-urls`, which includes `https://127.0.0.1:2379`; and the certificate flags `--trusted-ca-file`, `--cert-file` and `--key-file`. Those files are under `/etc/kubernetes/pki/etcd/`. The `etcdctl` client needs the same three files to be allowed to connect.

## Take a snapshot

Run this on the control-plane host. `etcdctl` is in the etcd container image, and it can be installed on the host as a package. The `ETCDCTL_API=3` variable selects the version 3 API, and the endpoint is the local client address:

```sh
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /var/backups/etcd-before-upgrade.db
```

The command reports that the snapshot was saved. Check the file. The `etcdutl` tool reads the file directly and does not need a running etcd; the older `etcdctl snapshot status` is deprecated in favor of it:

```sh
sudo etcdutl snapshot status /var/backups/etcd-before-upgrade.db --write-out=table
```

The table shows the hash, the revision, the total number of keys and the size. A file with a size of zero or a missing hash is not a usable snapshot.

A snapshot contains every Secret, and Secrets are stored in plain form in etcd unless encryption at rest is configured. Treat the file like a credential. Set its mode to `0600`, copy it to a protected location off the host, and delete old copies you do not need.

## Restore

A restore is a recovery action, not part of a normal upgrade. It writes a new data directory from the snapshot. Then you point the etcd static Pod at that directory:

```sh
sudo etcdutl snapshot restore /var/backups/etcd-before-upgrade.db --data-dir /var/lib/etcd-restored
```

Edit `/etc/kubernetes/manifests/etcd.yaml` so that the `hostPath` of the volume named `etcd-data` is `/var/lib/etcd-restored`. The kubelet recreates the etcd Pod with the restored data. A snapshot covers only the cluster state in etcd. Data in application databases and in volumes is not part of it and needs its own backup. State written after the snapshot is lost, so a restore returns the cluster to the time of the snapshot. With several control-plane nodes, the restore procedure has more steps, because every etcd member must start from the same snapshot.

## Verify after the upgrade

After the last node is done, check the cluster from top to bottom. The first command prints the nodes and their versions, which must all show the target version and the status `Ready`. The second command asks the API server for the result of its own health checks, one line for each check. The third lists Pods that are not running in any namespace:

```sh
kubectl get nodes
kubectl get --raw='/readyz?verbose'
kubectl get pods -A --field-selector=status.phase!=Running
```

The `readyz` output lists each check with `ok`, and ends with a line that says the check passed. The third command should show only finished jobs and nothing in a failed or pending state. Then test the application, not only the platform: send a request to a Service and check the answer. Also check `kubectl version` for the client and server versions, and `kubeadm certs check-expiration` on the control-plane host for the certificate dates.

If a node shows `NotReady` after the upgrade, read the kubelet log on that node with `journalctl -u kubelet`. If the API server does not answer, list the containers with `crictl ps -a` and read the log of the failing one.

You can now protect an upgrade with a snapshot, recover the state from it, and prove the result. That completes the cycle: know the versions, move the workloads, upgrade the components, and verify.

## Common pitfalls

> [!WARNING]
> - **Taking the snapshot without the three certificate options.** `etcdctl` cannot connect to the TLS endpoint.
> - **Not checking the snapshot.** Run `etcdutl snapshot status` and read the table.
> - **Leaving a snapshot readable by everyone.** It holds all Secrets. Use mode `0600` and store it off the host.
> - **Restoring and expecting recent changes to exist.** A restore returns to the time of the snapshot.
> - **Checking only `kubectl get nodes`.** Also check the API health, system Pods and one real application request.
