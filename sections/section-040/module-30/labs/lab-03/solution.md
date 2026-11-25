---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Restore etcd From A Snapshot: Solution

A restore turns a snapshot file back into an etcd data directory, and then etcd must run on that directory. On a kubeadm node, etcd is a static Pod, so you change its manifest and the kubelet starts a new etcd container. Connect with `astrona ssh astro-ats-032-lab-040-03-03` and run every command below on the VM.

The output below comes from one run of this lab. Hashes, revisions, IDs and times differ in your run.

## Step 1: Look at the starting state

The ConfigMap `fleet-roster` is missing, and `course-correction` exists. The snapshot is a root-only file:

```sh
kubectl -n starfleet-032-040-03-03 get configmaps
sudo ls -l /var/backups/etcd
sudo etcdutl snapshot status /var/backups/etcd/nightly.db --write-out=table
```

```text
NAME                DATA   AGE
course-correction   1      8s
kube-root-ca.crt    1      8s
total 732
-rw------- 1 root root 745504 Nov 18 08:58 nightly.db
+----------+----------+------------+------------+---------+
|   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE | VERSION |
+----------+----------+------------+------------+---------+
| 9a5ab1c2 |      392 |        308 |     746 kB |   3.6.0 |
+----------+----------+------------+------------+---------+
```

`etcdutl` reads the file directly and does not need a running etcd. The revision is the counter of the etcd key-value store when the snapshot was taken.

Now find where the manifest sets the data directory:

```sh
sudo grep -n "data-dir\|/var/lib/etcd\|etcd-data" /etc/kubernetes/manifests/etcd.yaml
```

```text
18:    - --data-dir=/var/lib/etcd
75:    - mountPath: /var/lib/etcd
76:      name: etcd-data
91:      path: /var/lib/etcd
93:    name: etcd-data
```

Three places name the directory. `--data-dir` (line 18) is the path inside the container. The volume mount (line 75) puts the volume `etcd-data` at that path. The `hostPath` (line 91) says which host directory the volume is. To switch etcd to new data, you only change the `hostPath`: the container keeps using `/var/lib/etcd`, but that path now shows the restored directory.

## Step 2: Restore the snapshot

`etcdutl snapshot restore` writes a new data directory. `--bump-revision` and `--mark-compacted` raise the revision far above any revision the API server has already seen and mark the older revisions as compacted. Without them, the API server and the controllers can keep cached objects with higher revisions than the restored data, and they do not notice the rollback:

```sh
sudo etcdutl snapshot restore /var/backups/etcd/nightly.db --data-dir /var/lib/etcd-restore --bump-revision 1000000000 --mark-compacted
sudo ls -l /var/lib/etcd-restore/member
```

The command prints one log line per step. The lines below are the start, the two revision steps and the end of this run; the `bbolt` lines and the member lines between them are left out:

```text
2026-11-18T08:59:01Z	info	snapshot/v3_snapshot.go:305	restoring snapshot	{"path": "/var/backups/etcd/nightly.db", "wal-dir": "/var/lib/etcd-restore/member/wal", "data-dir": "/var/lib/etcd-restore", "snap-dir": "/var/lib/etcd-restore/member/snap", "initial-memory-map-size": 10737418240}
2026-11-18T08:59:01Z	info	snapshot/v3_snapshot.go:396	bumping latest revision	{"latest-revision": 392, "bump-amount": 1000000000, "new-latest-revision": 1000000392}
2026-11-18T08:59:01Z	info	snapshot/v3_snapshot.go:413	marking revision compacted	{"revision": 1000000392}
2026-11-18T08:59:01Z	info	snapshot/v3_snapshot.go:333	restored snapshot	{"path": "/var/backups/etcd/nightly.db", "wal-dir": "/var/lib/etcd-restore/member/wal", "data-dir": "/var/lib/etcd-restore", "snap-dir": "/var/lib/etcd-restore/member/snap", "initial-memory-map-size": 10737418240}
total 8
drwx------ 2 root root 4096 Nov 18 08:59 snap
drwx------ 2 root root 4096 Nov 18 08:59 wal
```

The new directory has a `member` folder with the database (`snap`) and the write-ahead log (`wal`). The restore refuses a directory that already has content, so pick a new, empty path.

## Step 3: Point the etcd static Pod at the restored directory

Keep a copy of the manifest outside `/etc/kubernetes/manifests`, because the kubelet would start every manifest file in that folder. Then change only the `hostPath` line:

```sh
sudo cp /etc/kubernetes/manifests/etcd.yaml /root/etcd.yaml.before-restore
sudo sed -i 's#^\( *path: \)/var/lib/etcd$#\1/var/lib/etcd-restore#' /etc/kubernetes/manifests/etcd.yaml
sudo grep -n -B1 -A2 "path: /var/lib/etcd-restore" /etc/kubernetes/manifests/etcd.yaml
```

```text
90-  - hostPath:
91:      path: /var/lib/etcd-restore
92-      type: DirectoryOrCreate
93-    name: etcd-data
```

You can also make the same change with `sudo vi /etc/kubernetes/manifests/etcd.yaml`. The kubelet watches the folder, stops the old etcd container and starts a new one on the restored data. While etcd restarts, `kubectl` fails for some seconds.

## Step 4: Check etcd and the restored objects

Wait about a minute, then ask etcd for its status and list the ConfigMaps:

```sh
sudo etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key endpoint status --write-out=table
kubectl -n starfleet-032-040-03-03 get configmaps
kubectl -n kube-system get pods
```

The status table is wide; this copy keeps its first columns and leaves out the rest:

```text
+------------------------+------------------+---------+-----------------+---------+--------+
|        ENDPOINT        |        ID        | VERSION | STORAGE VERSION | DB SIZE | IN USE |
+------------------------+------------------+---------+-----------------+---------+--------+
| https://127.0.0.1:2379 | 8e9e05c52164694d |   3.6.6 |           3.6.0 |  918 kB | 471 kB |
+------------------------+------------------+---------+-----------------+---------+--------+
NAME               DATA   AGE
fleet-roster       3      89s
kube-root-ca.crt   1      89s
NAME                                   READY   STATUS    RESTARTS      AGE
coredns-7d764666f9-2frgf               1/1     Running   0             96s
coredns-7d764666f9-5cpcx               1/1     Running   0             96s
etcd-controlplane                      1/1     Running   0             11s
kube-apiserver-controlplane            1/1     Running   0             104s
kube-controller-manager-controlplane   1/1     Running   1 (65s ago)   104s
kube-proxy-g4d4w                       1/1     Running   0             97s
kube-scheduler-controlplane            0/1     Running   1 (59s ago)   104s
```

The member ID changed, because the restore writes new membership information. `fleet-roster` is back and `course-correction` is gone: the cluster now runs on the state of the snapshot. The controller manager and the scheduler restarted once, because they lost their leader lease while etcd was down. The scheduler becomes Ready a few seconds later. If the mirror Pod `etcd-controlplane` is missing for a short time, wait: the kubelet creates it again in the API server.

If etcd does not come back, read its container log with `sudo crictl ps -a --name etcd` and `sudo crictl logs <container-id>`. To undo, copy `/root/etcd.yaml.before-restore` back into `/etc/kubernetes/manifests/etcd.yaml`.
