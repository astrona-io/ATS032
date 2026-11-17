#!/usr/bin/env bash
# Reference solution: create the observer identity with get and list on Pods,
# and run the probe Deployment as that ServiceAccount.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-030-01-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
namespace=starfleet-032-030-01-01
kubectl -n "$namespace" create serviceaccount observer
kubectl -n "$namespace" create role observer-reader --verb=get,list --resource=pods
kubectl -n "$namespace" create rolebinding observer-read --role=observer-reader --serviceaccount="$namespace:observer"
kubectl -n "$namespace" set serviceaccount deployment probe observer
kubectl -n "$namespace" rollout status deployment/probe --timeout=180s
