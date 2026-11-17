#!/usr/bin/env bash
# Reference solution: harden the worker kubelet configuration
# (solution/harden-kubelet.sh runs inside the worker container) and wait until
# the restarted kubelet reports Webhook authorization.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-030-01-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-030-01-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
worker="$cluster-worker"
"$engine" exec -i "$worker" bash -s < "$lab_directory/solution/harden-kubelet.sh"
for attempt in $(seq 1 60); do
  mode=$(kubectl get --raw "/api/v1/nodes/$worker/proxy/configz" 2>/dev/null \
    | python3 -c 'import json, sys; print(json.load(sys.stdin)["kubeletconfig"]["authorization"]["mode"])' 2>/dev/null || true)
  if [[ "$mode" == Webhook ]]; then
    break
  fi
  if [[ "$attempt" == 60 ]]; then
    printf 'The worker kubelet did not come back within three minutes\n' >&2
    exit 1
  fi
  sleep 3
done
kubectl wait --for=condition=Ready "node/$worker" --timeout=120s
