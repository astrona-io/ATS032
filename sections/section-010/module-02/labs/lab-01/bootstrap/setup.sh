#!/usr/bin/env bash
# Creates scout with edit everywhere (a ClusterRoleBinding) and edit in
# starfleet (a RoleBinding with a User subject), plus the grants of shuttle
# and starfleet-crew that must keep working.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-010-02-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
