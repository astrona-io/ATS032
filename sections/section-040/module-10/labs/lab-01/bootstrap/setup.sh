#!/usr/bin/env bash
# Start state: both probe Pods run on the worker, a PodDisruptionBudget that
# allows no disruption protects them, and the bare Pod drifter runs on the worker.
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
kubectl wait --for=condition=Ready node --all --timeout=180s
# The probe Pods tolerate the control plane taint. Cordon the control plane
# while they start, so that both land on the worker.
kubectl cordon "$control_plane_name"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet-032-040-01-01 rollout status deployment/probe --timeout=180s
kubectl uncordon "$control_plane_name"
sed "s/WORKER_NAME/$worker_name/" "$lab_directory/bootstrap/manifests/drifter.yaml" | kubectl apply -f -
kubectl -n outpost-032-040-01-01 wait --for=condition=Ready pod/drifter --timeout=180s
