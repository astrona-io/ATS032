#!/usr/bin/env bash
# Reference solution: delete the three bindings that give shuttle Pod reads
# in outpost, and keep shuttle-configmap-reader.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-010-01-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
kubectl delete rolebinding shuttle-view shuttle-pod-lister starfleet-workloads -n outpost-032-010-01-03 --ignore-not-found
