#!/usr/bin/env bash
# Reference solution: restore the nightly snapshot into a separate data
# directory with etcdutl inside the etcd Pod, then record the snapshot
# revision in the ConfigMap restore-drill. The live etcd keeps running.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-040-03-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
etcd_pod="$(kubectl -n kube-system get pods -l component=etcd -o jsonpath='{.items[0].metadata.name}')"
kubectl -n kube-system exec "$etcd_pod" -- etcdutl snapshot restore /var/lib/etcd/backup/nightly.db --data-dir /var/lib/etcd/drill
revision="$(kubectl -n kube-system exec "$etcd_pod" -- etcdutl snapshot status /var/lib/etcd/backup/nightly.db --write-out=json \
  | python3 -c 'import json, sys; print(json.loads(sys.stdin.read().strip().splitlines()[-1])["revision"])')"
kubectl -n starfleet-032-040-03-03 create configmap restore-drill \
  --from-literal=revision="$revision" --dry-run=client -o yaml | kubectl apply -f -
