#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-010-01-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
bootstrap_directory="$(cd "$(dirname "$0")" && pwd)"
kubectl apply -f "$bootstrap_directory/manifests/start.yaml"
if [[ "$(kubectl auth can-i list pods -n starfleet-032-010-01-01 --as=system:serviceaccount:starfleet-032-010-01-01:shuttle || true)" != "no" ]]; then
  printf 'Starting identity unexpectedly has Pod access\n' >&2
  exit 1
fi
