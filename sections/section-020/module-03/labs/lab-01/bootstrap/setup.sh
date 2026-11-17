#!/usr/bin/env bash
# Creates the ServiceAccounts ledger and archive and three over-broad bindings:
# edit for ledger in the whole cluster, and view for every ServiceAccount of the
# namespace through a RoleBinding and a ClusterRoleBinding.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-020-03-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
