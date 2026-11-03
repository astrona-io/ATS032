#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-032-lab-010-03-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
bootstrap_directory="$(cd "$(dirname "$0")" && pwd)"
kubectl apply -f "$bootstrap_directory/manifests/start.yaml"
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  if [[ "$(kubectl auth can-i get secrets -n outpost --as=jane --as-group=outpost-crew || true)" == "yes" ]]; then exit 0; fi
  sleep 1
done
printf 'Starting identity does not show the expected broad access\n' >&2
exit 1
