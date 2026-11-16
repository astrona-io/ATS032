#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-040-01-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-040-01-01}"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="$cluster-control-plane"
worker_name="$cluster-worker"
sed "s/astro-ats-032-lab-040-01-01-/$cluster-/g" "$solution_directory/poddisruptionbudget-probe.yaml" | kubectl apply -f -
kubectl cordon "$worker_name"
kubectl drain "$worker_name" --ignore-daemonsets --timeout=180s
kubectl uncordon "$worker_name"
sed "s/astro-ats-032-lab-040-01-01-/$cluster-/g" "$solution_directory/poddisruptionbudget-probe.yaml" | kubectl apply -f -
kubectl wait --for=condition=Ready node/"$worker_name" --timeout=180s
kubectl -n starfleet-032-040-01-01 rollout status deployment/probe --timeout=180s
