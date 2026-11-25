#!/usr/bin/env bash
# Reference solution: create no-api without token mounting and recreate the
# Pod as that account, with mounting also off in the Pod spec.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-020-01-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
solution_directory="$(cd "$(dirname "$0")" && pwd)"
kubectl apply -f "$solution_directory/serviceaccount-no-api.yaml"
kubectl -n starfleet-032-020-01-01 delete pod no-token-reader --ignore-not-found --wait=true
kubectl apply -f "$solution_directory/pod-no-token-reader.yaml"
kubectl -n starfleet-032-020-01-01 wait --for=condition=Ready pod/no-token-reader --timeout=180s
