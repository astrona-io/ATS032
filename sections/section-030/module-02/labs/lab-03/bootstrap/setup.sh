#!/usr/bin/env bash
# Creates a broad impersonation grant for the group helpdesk and adds
# AlwaysAllow to the API server (bootstrap/stage-authorization.sh runs inside
# the control plane container).
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-030-02-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-030-02-03}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
"$engine" exec -i "$cluster-control-plane" bash -s < "$lab_directory/bootstrap/stage-authorization.sh"
kubectl -n kube-system wait --for=condition=Ready "pod/kube-apiserver-$cluster-control-plane" --timeout=180s
