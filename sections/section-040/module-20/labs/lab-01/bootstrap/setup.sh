#!/usr/bin/env bash
# Start state: the Deployment probe runs a busybox tag that the bootstrap picks
# at random, so the learner must read the image and its digest from the cluster.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-040-02-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
tags=(1.36.1 1.37.0)
probe_tag="${tags[RANDOM % ${#tags[@]}]}"
sed "s/PROBE_TAG/$probe_tag/" "$lab_directory/bootstrap/manifests/start.yaml" | kubectl apply -f -
kubectl -n starfleet-032-040-02-01 rollout status deployment/probe --timeout=180s
