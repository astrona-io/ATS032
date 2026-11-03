#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-032-playground-040-03" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
worker2_name="astro-ats-032-playground-040-03-worker2"
kubectl taint nodes "$worker2_name" maintenance=patching:NoSchedule --overwrite
kubectl taint nodes "$worker2_name" maintenance=patching:NoSchedule-
kubectl apply -f "$solution_directory/poddisruptionbudget-probe.yaml"
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl wait --for=condition=Ready node --all --timeout=180s
