#!/usr/bin/env bash
# Reference solution: delete the three bindings to broad groups. The
# built-in system: bindings and the narrow grants stay.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-010-02-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
kubectl delete rolebinding everyone-view fleet-config -n outpost-032-010-02-02 --ignore-not-found
kubectl delete clusterrolebinding starfleet-automation --ignore-not-found
