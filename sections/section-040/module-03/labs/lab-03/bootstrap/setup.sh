#!/usr/bin/env bash
# Start state: a fresh snapshot /var/lib/etcd/backup/nightly.db on the control
# plane node, and no restored data directory at /var/lib/etcd/drill.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-040-03-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-040-03-03}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/namespace.yaml"
kubectl -n kube-system wait --for=condition=Ready pod -l component=etcd --timeout=120s
"$engine" exec "$cluster-control-plane" rm -rf /var/lib/etcd/drill /var/lib/etcd/backup
"$engine" exec "$cluster-control-plane" install -d -m 0700 /var/lib/etcd/backup
etcd_pod="$(kubectl -n kube-system get pods -l component=etcd -o jsonpath='{.items[0].metadata.name}')"
kubectl -n kube-system exec "$etcd_pod" -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /var/lib/etcd/backup/nightly.db
