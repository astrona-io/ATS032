#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-020-03-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"

kubectl -n outpost-032-020-03-01 delete secret ledger-legacy-token --ignore-not-found
kubectl delete clusterrolebinding ledger-edit --ignore-not-found
kubectl -n outpost-032-020-03-01 delete rolebinding outpost-all-view --ignore-not-found
kubectl apply -f "$solution_directory/rbac-config-reader.yaml"
kubectl -n outpost-032-020-03-01 delete pod ledger-client --ignore-not-found --wait=true
kubectl apply -f "$solution_directory/pod-ledger-client.yaml"
kubectl -n outpost-032-020-03-01 wait --for=condition=Ready pod/ledger-client --timeout=180s
