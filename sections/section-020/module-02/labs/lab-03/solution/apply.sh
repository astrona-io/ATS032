#!/usr/bin/env bash
# Reference solution: remove the grants to default, turn token mounting off on
# both default ServiceAccounts and recreate the two Pods.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-020-02-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
solution_directory="$(cd "$(dirname "$0")" && pwd)"
kubectl -n starfleet-032-020-02-03 delete rolebinding default-pod-access --ignore-not-found
kubectl -n outpost-032-020-02-03 delete rolebinding drifter-view --ignore-not-found
for namespace in starfleet-032-020-02-03 outpost-032-020-02-03; do
  kubectl -n "$namespace" patch serviceaccount default -p '{"automountServiceAccountToken": false}'
done
kubectl -n starfleet-032-020-02-03 delete pod shuttle --ignore-not-found --wait=true
kubectl -n outpost-032-020-02-03 delete pod drifter --ignore-not-found --wait=true
kubectl apply -f "$solution_directory/pod-shuttle.yaml"
kubectl apply -f "$solution_directory/pod-drifter.yaml"
kubectl -n starfleet-032-020-02-03 wait --for=condition=Ready pod/shuttle --timeout=180s
kubectl -n outpost-032-020-02-03 wait --for=condition=Ready pod/drifter --timeout=180s
