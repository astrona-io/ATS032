#!/usr/bin/env bash
# Reference solution: create the backup directory on the control plane node,
# run etcdctl inside the etcd Pod to save the snapshot, read its revision with
# etcdutl and record it in the ConfigMap snapshot-record.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-040-01-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-040-01-03}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
"$engine" exec "$cluster-control-plane" install -d -m 0700 /var/lib/etcd/backup
etcd_pod="$(kubectl -n kube-system get pods -l component=etcd -o jsonpath='{.items[0].metadata.name}')"
kubectl -n kube-system exec "$etcd_pod" -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /var/lib/etcd/backup/pre-upgrade.db
revision="$(kubectl -n kube-system exec "$etcd_pod" -- etcdutl snapshot status /var/lib/etcd/backup/pre-upgrade.db --write-out=json \
  | python3 -c 'import json, sys; print(json.loads(sys.stdin.read().strip().splitlines()[-1])["revision"])')"
kubectl -n starfleet-032-040-01-03 create configmap snapshot-record \
  --from-literal=revision="$revision" --dry-run=client -o yaml | kubectl apply -f -
