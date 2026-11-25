#!/usr/bin/env bash
# Reference solution: delete the long-lived token Secrets and recreate
# ledger-client with a token that lives one hour.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-020-03-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
solution_directory="$(cd "$(dirname "$0")" && pwd)"
kubectl -n outpost-032-020-03-02 delete secret ledger-legacy-token archive-credentials --ignore-not-found
kubectl -n outpost-032-020-03-02 delete pod ledger-client --ignore-not-found --wait=true
kubectl apply -f "$solution_directory/pod-ledger-client.yaml"
kubectl -n outpost-032-020-03-02 wait --for=condition=Ready pod/ledger-client --timeout=180s
