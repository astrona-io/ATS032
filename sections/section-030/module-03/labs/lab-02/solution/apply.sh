#!/usr/bin/env bash
# Reference solution: extend the policy to UPDATE requests and bind it with
# the Deny action to the outpost namespace only.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-030-03-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/solution/vap-deny-nodeport.yaml"
kubectl apply -f "$lab_directory/solution/vapb-deny-nodeport-outpost.yaml"
