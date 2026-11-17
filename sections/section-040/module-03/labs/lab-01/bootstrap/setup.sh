#!/usr/bin/env bash
# Start state: an unfinished maintenance window. The worker is still cordoned
# and tainted, one probe Pod is Pending, and the budget allows no disruption.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-040-03-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-040-03-01}"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
namespace="starfleet-032-040-03-01"
worker_name="$cluster-worker"
kubectl wait --for=condition=Ready node --all --timeout=180s
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n "$namespace" rollout status deployment/probe --timeout=180s
kubectl apply -f "$lab_directory/bootstrap/manifests/poddisruptionbudget-probe.yaml"
kubectl cordon "$worker_name"
kubectl taint nodes "$worker_name" maintenance=patching:NoSchedule --overwrite
# The Pod that ran on the worker is gone; its replacement cannot be scheduled.
kubectl -n "$namespace" delete pod -l app=probe --field-selector spec.nodeName="$worker_name" --timeout=60s
