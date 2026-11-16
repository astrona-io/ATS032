#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-040-capstone-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-040-capstone-01}"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
worker_name="$cluster-worker"

read_node_field() {
  kubectl get node "$1" -o "jsonpath={.status.nodeInfo.$2}"
}

kubectl apply -f "$solution_directory/poddisruptionbudget-probe.yaml"
kubectl -n outpost delete pod drifter --timeout=60s
sed "s/astro-ats-032-lab-040-capstone-01-/$cluster-/g" "$solution_directory/pod-drifter.yaml" | kubectl apply -f -
kubectl -n outpost wait --for=condition=Ready pod/drifter --timeout=120s
kubectl drain "$worker_name" --ignore-daemonsets --timeout=180s
kubectl label node "$worker_name" patch-status=done --overwrite

server_version="$(kubectl get --raw /version | python3 -c 'import json, sys; print(json.load(sys.stdin)["gitVersion"])')"
probe_image="$(kubectl -n starfleet get deployment probe -o jsonpath='{.spec.template.spec.containers[0].image}')"
rendered_file="$(mktemp)"
trap 'command rm -f "$rendered_file"' EXIT
sed \
  -e "s|<SERVER_VERSION>|$server_version|" \
  -e "s|<KUBELET_WORKER>|$(read_node_field "$worker_name" kubeletVersion)|" \
  -e "s|<CONTAINER_RUNTIME_WORKER>|$(read_node_field "$worker_name" containerRuntimeVersion)|" \
  -e "s|<PROBE_IMAGE>|$probe_image|" \
  "$solution_directory/version-inventory.yaml.template" > "$rendered_file"
kubectl apply -f "$rendered_file"

kubectl uncordon "$worker_name"
kubectl taint nodes "$worker_name" maintenance=patching:NoSchedule-
kubectl -n starfleet rollout status deployment/probe --timeout=180s
kubectl wait --for=condition=Ready node --all --timeout=180s
