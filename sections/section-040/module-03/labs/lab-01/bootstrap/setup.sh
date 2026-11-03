#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-032-lab-040-03-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
worker2_name="astro-ats-032-lab-040-03-01-worker2"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod/shuttle --timeout=120s
kubectl -n outpost wait --for=condition=Ready pod/drifter --timeout=120s
# Leave the second worker in the state of an unfinished maintenance window.
kubectl cordon "$worker2_name"
kubectl taint nodes "$worker2_name" maintenance=patching:NoSchedule --overwrite
stale_pod="$(kubectl -n starfleet get pods -l app=probe --field-selector spec.nodeName="$worker2_name" -o name)"
kubectl -n starfleet delete "$stale_pod" --timeout=60s
