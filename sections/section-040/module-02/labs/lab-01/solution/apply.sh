#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-040-02-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-040-02-01}"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
control_plane_name="$cluster-control-plane"
worker_name="$cluster-worker"
worker2_name="$cluster-worker2"

read_node_field() {
  kubectl get node "$1" -o "jsonpath={.status.nodeInfo.$2}"
}

server_version="$(kubectl get --raw /version | python3 -c 'import json, sys; print(json.load(sys.stdin)["gitVersion"])')"
probe_image="$(kubectl -n starfleet-032-040-02-01 get deployment probe -o jsonpath='{.spec.template.spec.containers[0].image}')"
client_image="$(kubectl -n outpost-032-040-02-01 get pod drifter -o jsonpath='{.spec.containers[0].image}')"
rendered_file="$(mktemp)"
trap 'command rm -f "$rendered_file"' EXIT
sed \
  -e "s|<SERVER_VERSION>|$server_version|" \
  -e "s|<KUBELET_CONTROL_PLANE>|$(read_node_field "$control_plane_name" kubeletVersion)|" \
  -e "s|<KUBELET_WORKER>|$(read_node_field "$worker_name" kubeletVersion)|" \
  -e "s|<KUBELET_WORKER2>|$(read_node_field "$worker2_name" kubeletVersion)|" \
  -e "s|<CONTAINER_RUNTIME>|$(read_node_field "$control_plane_name" containerRuntimeVersion)|" \
  -e "s|<PROBE_IMAGE>|$probe_image|" \
  -e "s|<CLIENT_IMAGE>|$client_image|" \
  "$solution_directory/version-inventory.yaml.template" > "$rendered_file"
kubectl apply -f "$rendered_file"
kubectl label node "$control_plane_name" patch-wave=1 --overwrite
kubectl label node "$worker_name" patch-wave=2 --overwrite
kubectl label node "$worker2_name" patch-wave=3 --overwrite
