#!/usr/bin/env bash
# Creates the lab namespace and the Pod no-token-reader, which runs as the
# default ServiceAccount and therefore has a token mounted.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-020-01-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet-032-020-01-01 wait --for=condition=Ready pod/no-token-reader --timeout=180s
