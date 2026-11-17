#!/usr/bin/env bash
# Turns on static token authentication in the API server
# (bootstrap/stage-token.sh runs inside the control plane container).
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-030-02-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-030-02-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
"$engine" exec -i "$cluster-control-plane" bash -s < "$lab_directory/bootstrap/stage-token.sh"
kubectl apply -f "$lab_directory/bootstrap/manifests/namespace.yaml"
kubectl -n kube-system wait --for=condition=Ready "pod/kube-apiserver-$cluster-control-plane" --timeout=180s
