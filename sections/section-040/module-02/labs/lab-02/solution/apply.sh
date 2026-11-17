#!/usr/bin/env bash
# Reference solution: compare every record of advisory-feed with the running
# versions, write the affected IDs to the ConfigMap triage and label the nodes
# with their patch wave.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-040-02-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-040-02-02}"
namespace="starfleet-032-040-02-02"
kubelet_version="$(kubectl get node "$cluster-worker" -o jsonpath='{.status.nodeInfo.kubeletVersion}')"
etcd_image="$(kubectl -n kube-system get pods -l component=etcd -o jsonpath='{.items[0].spec.containers[0].image}')"
coredns_image="$(kubectl -n kube-system get pods -l k8s-app=kube-dns -o jsonpath='{.items[0].spec.containers[0].image}')"
probe_image="$(kubectl -n "$namespace" get deployment probe -o jsonpath='{.spec.template.spec.containers[0].image}')"
affected="$(kubectl -n "$namespace" get configmap advisory-feed -o jsonpath='{.data.records}' | python3 -c '
import sys
def plain(version):
    return tuple(int(part) for part in version.lstrip("v").split("-")[0].split(".")[:3])
running = {"kubelet": plain(sys.argv[1]), "etcd": plain(sys.argv[2].rsplit(":", 1)[1]),
           "coredns": plain(sys.argv[3].rsplit(":", 1)[1]), "busybox": plain(sys.argv[4].rsplit(":", 1)[1])}
for line in sys.stdin.read().splitlines()[1:]:
    identifier, component, introduced, fixed = line.split()[:4]
    if plain(introduced) <= running[component] < plain(fixed):
        print(identifier)
' "$kubelet_version" "$etcd_image" "$coredns_image" "$probe_image")"
kubectl -n "$namespace" create configmap triage --from-literal=affected="$affected" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl label node "$cluster-control-plane" patch-wave=1 --overwrite
kubectl label node "$cluster-worker" patch-wave=2 --overwrite
