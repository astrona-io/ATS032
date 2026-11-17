#!/usr/bin/env bash
# Creates the lab namespace and the ConfigMap upgrade-ticket. The grader checks
# that the snapshot is newer than this ConfigMap, so a snapshot from an earlier
# start cannot pass. Any old snapshot at the task path is removed.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-040-01-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-040-01-03}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/namespace.yaml"
"$engine" exec "$cluster-control-plane" rm -rf /var/lib/etcd/backup
kubectl -n starfleet-032-040-01-03 create configmap upgrade-ticket \
  --from-literal=ticket="CHG-$((RANDOM % 9000 + 1000))" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n kube-system wait --for=condition=Ready pod -l component=etcd --timeout=120s
