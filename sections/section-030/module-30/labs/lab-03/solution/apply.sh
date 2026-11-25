#!/usr/bin/env bash
# Reference solution: make the image-review webhook fail closed with a short
# timeout and keep kube-system out of its namespace selector.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-030-03-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/solution/validatingwebhookconfiguration-image-review.yaml"
