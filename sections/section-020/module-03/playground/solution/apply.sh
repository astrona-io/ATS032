#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-032-playground-020-03" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"

kubectl -n outpost delete secret ledger-legacy-token --ignore-not-found
kubectl delete clusterrolebinding ledger-edit --ignore-not-found
kubectl -n outpost delete rolebinding outpost-all-view --ignore-not-found
kubectl apply -f "$solution_directory/rbac-config-reader.yaml"
kubectl -n outpost delete pod ledger-client --ignore-not-found --wait=true
kubectl apply -f "$solution_directory/pod-ledger-client.yaml"
kubectl -n outpost wait --for=condition=Ready pod/ledger-client --timeout=180s
