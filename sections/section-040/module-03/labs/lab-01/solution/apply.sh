#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-040-03-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-040-03-01}"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
worker2_name="$cluster-worker2"
kubectl uncordon "$worker2_name"
kubectl taint nodes "$worker2_name" maintenance=patching:NoSchedule-
kubectl apply -f "$solution_directory/poddisruptionbudget-probe.yaml"
kubectl -n starfleet-032-040-03-01 rollout status deployment/probe --timeout=180s
kubectl wait --for=condition=Ready node --all --timeout=180s
