#!/usr/bin/env bash
# Reference solution: finish the maintenance window. Remove the taint, uncordon
# the worker, wait for the probe rollout and replace the budget.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-040-03-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-040-03-01}"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
worker_name="$cluster-worker"
kubectl taint nodes "$worker_name" maintenance=patching:NoSchedule-
kubectl uncordon "$worker_name"
kubectl wait --for=condition=Ready node --all --timeout=180s
kubectl -n starfleet-032-040-03-01 rollout status deployment/probe --timeout=180s
kubectl apply -f "$lab_directory/solution/poddisruptionbudget-probe.yaml"
