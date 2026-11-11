#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-040-03-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-040-03-01}"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
worker2_name="$cluster-worker2"
# The client pods select their node by name; use this cluster's node names.
sed "s/astro-ats-032-lab-040-03-01-/$cluster-/g" "$lab_directory/bootstrap/manifests/start.yaml" | kubectl apply -f -
kubectl -n starfleet-032-040-03-01 rollout status deployment/probe --timeout=180s
kubectl -n starfleet-032-040-03-01 wait --for=condition=Ready pod/shuttle --timeout=120s
kubectl -n outpost-032-040-03-01 wait --for=condition=Ready pod/drifter --timeout=120s
# Leave the second worker in the state of an unfinished maintenance window.
kubectl cordon "$worker2_name"
kubectl taint nodes "$worker2_name" maintenance=patching:NoSchedule --overwrite
stale_pod="$(kubectl -n starfleet-032-040-03-01 get pods -l app=probe --field-selector spec.nodeName="$worker2_name" -o name)"
kubectl -n starfleet-032-040-03-01 delete "$stale_pod" --timeout=60s
