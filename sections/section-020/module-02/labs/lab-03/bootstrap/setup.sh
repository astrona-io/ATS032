#!/usr/bin/env bash
# Creates two namespaces in which the default ServiceAccount has permissions
# through RoleBindings, and one Pod in each that runs with its token.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-020-02-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet-032-020-02-03 wait --for=condition=Ready pod/shuttle --timeout=180s
kubectl -n outpost-032-020-02-03 wait --for=condition=Ready pod/drifter --timeout=180s
