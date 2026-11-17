#!/usr/bin/env bash
# Reference solution: drain the worker, restart containerd inside the worker
# node container, wait for the node to be Ready and uncordon it.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-040-03-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-040-03-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
worker_name="$cluster-worker"
kubectl drain "$worker_name" --ignore-daemonsets --timeout=180s
"$engine" exec "$worker_name" systemctl restart containerd
"$engine" exec "$worker_name" systemctl is-active containerd
kubectl wait --for=condition=Ready node/"$worker_name" --timeout=180s
kubectl uncordon "$worker_name"
kubectl -n starfleet-032-040-03-02 rollout status deployment/probe --timeout=180s
