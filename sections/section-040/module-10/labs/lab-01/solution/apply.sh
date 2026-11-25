#!/usr/bin/env bash
# Reference solution: relax the budget, move the bare Pod drifter to the
# control plane node, then drain the worker and leave it cordoned.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-040-01-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-040-01-01}"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
control_plane_name="$cluster-control-plane"
worker_name="$cluster-worker"
kubectl apply -f "$lab_directory/solution/poddisruptionbudget-probe.yaml"
kubectl -n outpost-032-040-01-01 delete pod drifter --wait=true --timeout=120s
sed "s/CONTROL_PLANE_NAME/$control_plane_name/" "$lab_directory/solution/pod-drifter.yaml" | kubectl apply -f -
kubectl -n outpost-032-040-01-01 wait --for=condition=Ready pod/drifter --timeout=180s
kubectl drain "$worker_name" --ignore-daemonsets --timeout=180s
kubectl -n starfleet-032-040-01-01 rollout status deployment/probe --timeout=180s
