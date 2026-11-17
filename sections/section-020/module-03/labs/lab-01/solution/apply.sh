#!/usr/bin/env bash
# Reference solution: delete the three over-broad bindings and give ledger only
# get and list on ConfigMaps in its namespace.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-020-03-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
solution_directory="$(cd "$(dirname "$0")" && pwd)"
kubectl delete clusterrolebinding ledger-edit outpost-view-all --ignore-not-found
kubectl -n outpost-032-020-03-01 delete rolebinding outpost-all-view --ignore-not-found
kubectl apply -f "$solution_directory/role-config-reader.yaml"
kubectl apply -f "$solution_directory/rolebinding-config-reader.yaml"
