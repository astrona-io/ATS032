#!/usr/bin/env bash
# Reference solution: remove static token authentication from the API server
# (solution/remove-token-file.sh runs inside the control plane container).
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-030-02-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-030-02-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
"$engine" exec -i "$cluster-control-plane" bash -s < "$lab_directory/solution/remove-token-file.sh"
