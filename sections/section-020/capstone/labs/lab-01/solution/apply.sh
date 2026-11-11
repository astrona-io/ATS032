#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-020-capstone-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"

kubectl apply -f "$solution_directory/serviceaccount-probe.yaml"
kubectl -n starfleet set serviceaccount deployment/probe probe
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n starfleet delete rolebinding default-pod-access --ignore-not-found
kubectl -n starfleet patch serviceaccount default -p '{"automountServiceAccountToken": false}'
kubectl apply -f "$solution_directory/rbac-shuttle-reader.yaml"
kubectl -n starfleet delete pod shuttle --ignore-not-found --wait=true
kubectl apply -f "$solution_directory/pod-shuttle.yaml"
kubectl -n outpost delete secret drifter-legacy-token --ignore-not-found
kubectl delete clusterrolebinding outpost-view-all --ignore-not-found
kubectl -n outpost delete pod drifter --ignore-not-found --wait=true
kubectl apply -f "$solution_directory/pod-drifter.yaml"
kubectl -n starfleet wait --for=condition=Ready pod/shuttle --timeout=180s
kubectl -n outpost wait --for=condition=Ready pod/drifter --timeout=180s
