#!/usr/bin/env bash
# Start state: both probe Pods run on the worker, and the worker is cordoned
# but not drained. The ConfigMap
# maintenance-baseline records when containerd on the worker last started and
# the UIDs of the probe Pods, so the grader can tell what changed.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-040-03-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-040-03-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
namespace="starfleet-032-040-03-02"
control_plane_name="$cluster-control-plane"
worker_name="$cluster-worker"
kubectl wait --for=condition=Ready node --all --timeout=180s
# The probe Pods tolerate the control plane taint. Cordon the control plane
# while they start, so that both land on the worker.
kubectl cordon "$control_plane_name"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n "$namespace" rollout status deployment/probe --timeout=180s
kubectl uncordon "$control_plane_name"
runtime_started="$("$engine" exec "$worker_name" systemctl show containerd --property=ActiveEnterTimestampMonotonic --value)"
probe_uids="$(kubectl -n "$namespace" get pods -l app=probe -o jsonpath='{.items[*].metadata.uid}')"
kubectl -n "$namespace" create configmap maintenance-baseline \
  --from-literal=containerd-started="$runtime_started" \
  --from-literal=probe-uids="$probe_uids" \
  --dry-run=client -o yaml | kubectl apply -f -
# The maintenance window has opened: the worker is cordoned, but nothing has
# been evicted yet.
kubectl cordon "$worker_name"
