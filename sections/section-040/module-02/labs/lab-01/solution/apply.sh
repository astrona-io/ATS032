#!/usr/bin/env bash
# Reference solution: read every value from the live cluster and write the
# ConfigMap version-inventory.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-040-02-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-040-02-01}"
control_plane_name="$cluster-control-plane"
worker_name="$cluster-worker"
namespace="starfleet-032-040-02-01"

read_node_field() {
  kubectl get node "$1" -o "jsonpath={.status.nodeInfo.$2}"
}

server_version="$(kubectl get --raw /version | python3 -c 'import json, sys; print(json.load(sys.stdin)["gitVersion"])')"
etcd_image="$(kubectl -n kube-system get pods -l component=etcd -o jsonpath='{.items[0].spec.containers[0].image}')"
coredns_image="$(kubectl -n kube-system get pods -l k8s-app=kube-dns -o jsonpath='{.items[0].spec.containers[0].image}')"
probe_image="$(kubectl -n "$namespace" get deployment probe -o jsonpath='{.spec.template.spec.containers[0].image}')"
probe_image_id="$(kubectl -n "$namespace" get pods -l app=probe -o jsonpath='{.items[0].status.containerStatuses[0].imageID}')"
probe_digest="sha256:${probe_image_id##*sha256:}"
kubectl -n "$namespace" create configmap version-inventory \
  --from-literal=server-version="$server_version" \
  --from-literal=kubelet-control-plane="$(read_node_field "$control_plane_name" kubeletVersion)" \
  --from-literal=kubelet-worker="$(read_node_field "$worker_name" kubeletVersion)" \
  --from-literal=container-runtime="$(read_node_field "$worker_name" containerRuntimeVersion)" \
  --from-literal=etcd-image="$etcd_image" \
  --from-literal=coredns-image="$coredns_image" \
  --from-literal=probe-image="$probe_image" \
  --from-literal=probe-digest="$probe_digest" \
  --dry-run=client -o yaml | kubectl apply -f -
