#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-032-playground-040-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="astro-ats-032-playground-040-01-control-plane"
worker_name="astro-ats-032-playground-040-01-worker"
kubectl apply -f "$solution_directory/poddisruptionbudget-probe.yaml"
kubectl cordon "$worker_name"
kubectl drain "$worker_name" --ignore-daemonsets --timeout=180s
kubectl uncordon "$worker_name"
kubectl apply -f "$solution_directory/poddisruptionbudget-probe.yaml"
kubectl wait --for=condition=Ready node/"$worker_name" --timeout=180s
kubectl -n starfleet rollout status deployment/probe --timeout=180s
