#!/usr/bin/env bash
# Reference solution: view in outpost through a RoleBinding, and the
# role-manager Role with its RoleBinding.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-010-01-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
solution_directory="$(cd "$(dirname "$0")" && pwd)"
kubectl apply -f "$solution_directory/rolebinding-shuttle-view.yaml"
kubectl apply -f "$solution_directory/role-role-manager.yaml"
