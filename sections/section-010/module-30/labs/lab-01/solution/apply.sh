#!/usr/bin/env bash
# Reference solution: replace the wildcard rules and remove the second grant
# of outpost-crew.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-010-03-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
solution_directory="$(cd "$(dirname "$0")" && pwd)"
kubectl apply -f "$solution_directory/role-crew-operator.yaml"
kubectl delete rolebinding crew-maintenance -n starfleet-032-010-03-01 --ignore-not-found
