#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-040-01-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-040-01-01}"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_name="$cluster-control-plane"
worker_name="$cluster-worker"
# The client pods select their node by name; use this cluster's node names.
sed "s/astro-ats-032-lab-040-01-01-/$cluster-/g" "$lab_directory/bootstrap/manifests/start.yaml" | kubectl apply -f -
kubectl -n starfleet-032-040-01-01 rollout status deployment/probe --timeout=180s
kubectl -n starfleet-032-040-01-01 wait --for=condition=Ready pod/shuttle --timeout=120s
kubectl -n outpost-032-040-01-01 wait --for=condition=Ready pod/drifter --timeout=120s

