#!/usr/bin/env bash
# Creates the namespaces, a ClusterIP Service and a ValidatingAdmissionPolicy
# that checks only CREATE requests and has no binding yet.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-030-03-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
