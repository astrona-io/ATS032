#!/usr/bin/env bash
# Creates the namespaces starfleet-032-020-02-02 and outpost-032-020-02-02 and
# the Pod shuttle, which runs as the default ServiceAccount.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-020-02-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet-032-020-02-02 wait --for=condition=Ready pod/shuttle --timeout=180s
kubectl -n outpost-032-020-02-02 wait --for=condition=Ready pod/drifter --timeout=180s
