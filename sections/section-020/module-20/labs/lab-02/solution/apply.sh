#!/usr/bin/env bash
# Reference solution: the ServiceAccount shuttle-reader with a Role that can only
# get and list Pods, and the Pod shuttle with a projected token.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-020-02-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
solution_directory="$(cd "$(dirname "$0")" && pwd)"
kubectl apply -f "$solution_directory/serviceaccount-shuttle-reader.yaml"
kubectl apply -f "$solution_directory/role-shuttle-reader.yaml"
kubectl apply -f "$solution_directory/rolebinding-shuttle-reader.yaml"
kubectl -n starfleet-032-020-02-02 delete pod shuttle --ignore-not-found --wait=true
kubectl apply -f "$solution_directory/pod-shuttle.yaml"
kubectl -n starfleet-032-020-02-02 wait --for=condition=Ready pod/shuttle --timeout=180s
