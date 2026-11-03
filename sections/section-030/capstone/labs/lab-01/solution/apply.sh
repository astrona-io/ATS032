#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-032-lab-030-capstone-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
kubectl apply -f "$solution_directory/capstone.yaml"
kubectl -n starfleet set serviceaccount deployment/probe lister
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl delete clusterrolebinding anonymous-viewer --ignore-not-found
kubectl label namespace starfleet pod-security.kubernetes.io/enforce=baseline --overwrite
