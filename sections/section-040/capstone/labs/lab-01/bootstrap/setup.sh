#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-040-capstone-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-040-capstone-01}"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
worker_name="$cluster-worker"
# The pods select their node by name; use this cluster's node names.
sed "s/astro-ats-032-lab-040-capstone-01-/$cluster-/g" "$lab_directory/bootstrap/manifests/start.yaml" | kubectl apply -f -
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl -n starfleet wait --for=condition=Ready pod/shuttle --timeout=120s
kubectl -n outpost wait --for=condition=Ready pod/drifter --timeout=120s
# Record the probe pod that runs on the first worker now, so the grader can tell it was replaced.
original_uid="$(kubectl -n starfleet get pods -l app=probe --field-selector spec.nodeName="$worker_name" -o jsonpath='{.items[0].metadata.uid}')"
kubectl -n starfleet create configmap maintenance-baseline --from-literal=probe-pod-uid-on-worker="$original_uid" --dry-run=client -o yaml | kubectl apply -f -
# Leave the first worker in the state of a maintenance window that has just started.
kubectl cordon "$worker_name"
kubectl taint nodes "$worker_name" maintenance=patching:NoSchedule --overwrite
