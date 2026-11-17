#!/usr/bin/env bash
# Creates the ServiceAccount reporter, a long-lived token Secret for it and the
# Pod ledger-client, which reads that Secret as its token.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-020-01-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n outpost-032-020-01-02 wait --for=condition=Ready pod/ledger-client --timeout=180s
