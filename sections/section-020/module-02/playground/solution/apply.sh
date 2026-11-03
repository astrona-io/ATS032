#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-032-playground-020-02" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"

kubectl apply -f "$solution_directory/serviceaccount-probe.yaml"
kubectl -n starfleet set serviceaccount deployment/probe probe
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl apply -f "$solution_directory/rbac-pod-lister.yaml"
kubectl apply -f "$solution_directory/pod-pod-lister.yaml"
kubectl -n starfleet delete rolebinding default-pod-access --ignore-not-found
kubectl -n starfleet patch serviceaccount default -p '{"automountServiceAccountToken": false}'
kubectl -n starfleet wait --for=condition=Ready pod/pod-lister --timeout=180s
