#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-032-playground-020-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="astro-ats-032-playground-020-01-control-plane"
worker_name="astro-ats-032-playground-020-01-worker"

kubectl apply -f "$solution_directory/serviceaccount-no-api.yaml"
kubectl -n starfleet wait --for=condition=Ready pod/no-token-reader --timeout=180s
