#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-032-playground-030-03" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
kubectl label namespace outpost pod-security.kubernetes.io/enforce=baseline --overwrite
kubectl apply -f "$solution_directory/admission-outpost.yaml"
