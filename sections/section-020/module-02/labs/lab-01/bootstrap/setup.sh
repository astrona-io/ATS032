#!/usr/bin/env bash
# Creates the lab namespace and the Deployment probe, whose Pods run as the
# default ServiceAccount and therefore have a token mounted.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-020-02-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet-032-020-02-01 rollout status deployment/probe --timeout=180s
