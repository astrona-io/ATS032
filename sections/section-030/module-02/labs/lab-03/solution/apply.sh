#!/usr/bin/env bash
# Reference solution: remove AlwaysAllow from the API server
# (solution/remove-always-allow.sh runs inside the control plane container),
# then narrow the impersonation grant of the group helpdesk to one
# ServiceAccount in one namespace.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-030-02-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-030-02-03}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
"$engine" exec -i "$cluster-control-plane" bash -s < "$lab_directory/solution/remove-always-allow.sh"
kubectl apply -f "$lab_directory/solution/clusterrole-helpdesk-impersonate.yaml"
kubectl delete clusterrolebinding helpdesk-impersonate
