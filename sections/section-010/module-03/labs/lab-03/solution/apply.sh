#!/usr/bin/env bash
# Reference solution: two labelled ClusterRoles, the aggregated ClusterRole
# fleet-reader, and a RoleBinding of it for probe in dock.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-010-03-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
solution_directory="$(cd "$(dirname "$0")" && pwd)"
kubectl apply -f "$solution_directory/clusterroles-fleet-reader.yaml"
kubectl apply -f "$solution_directory/rolebinding-probe-fleet-reader.yaml"
