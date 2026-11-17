#!/usr/bin/env bash
# Reference solution: delete the two bindings that name anonymous subjects.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-030-02-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
kubectl delete clusterrolebinding metrics-reader
kubectl -n starfleet-032-030-02-01 delete rolebinding support-read
