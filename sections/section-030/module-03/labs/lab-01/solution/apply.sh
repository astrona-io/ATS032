#!/usr/bin/env bash
# Reference solution: label the namespace with enforce=baseline and
# warn=restricted, then apply the web Deployment without privileged mode.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-030-03-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
namespace=outpost-032-030-03-01
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl label namespace "$namespace" --overwrite \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/warn=restricted
kubectl apply -f "$lab_directory/solution/deployment-web.yaml"
kubectl -n "$namespace" rollout status deployment/web --timeout=180s
