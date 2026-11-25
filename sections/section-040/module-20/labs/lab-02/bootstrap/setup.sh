#!/usr/bin/env bash
# Start state: the Deployment probe runs a busybox tag picked at random, and the
# ConfigMap advisory-feed holds made-up vulnerability records built from the
# versions that this cluster runs.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-040-02-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-040-02-02}"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
namespace="starfleet-032-040-02-02"
tags=(1.36.1 1.37.0)
probe_tag="${tags[RANDOM % ${#tags[@]}]}"
sed "s/PROBE_TAG/$probe_tag/" "$lab_directory/bootstrap/manifests/start.yaml" | kubectl apply -f -
kubectl -n "$namespace" rollout status deployment/probe --timeout=180s

# A version without the leading "v" and without a "-suffix": v1.13.1 -> 1.13.1, 3.6.6-0 -> 3.6.6
plain_version() {
  local version="${1#v}"
  printf '%s\n' "${version%%-*}"
}
image_tag() {
  printf '%s\n' "${1##*:}"
}
kubelet_version="$(kubectl get node "$cluster-worker" -o jsonpath='{.status.nodeInfo.kubeletVersion}')"
etcd_image="$(kubectl -n kube-system get pods -l component=etcd -o jsonpath='{.items[0].spec.containers[0].image}')"
coredns_image="$(kubectl -n kube-system get pods -l k8s-app=kube-dns -o jsonpath='{.items[0].spec.containers[0].image}')"
feed_file="$(mktemp)"
trap 'command rm -f "$feed_file"' EXIT
python3 "$lab_directory/bootstrap/feed.py" \
  "kubelet=$(plain_version "$kubelet_version")" \
  "etcd=$(plain_version "$(image_tag "$etcd_image")")" \
  "coredns=$(plain_version "$(image_tag "$coredns_image")")" \
  "busybox=$probe_tag" > "$feed_file"
kubectl -n "$namespace" create configmap advisory-feed --from-file=records="$feed_file" \
  --dry-run=client -o yaml | kubectl apply -f -
