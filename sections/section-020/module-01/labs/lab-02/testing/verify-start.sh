#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-020-01-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-020-01-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
[[ "$(kubectl config current-context)" == "$context" ]] || { echo 'ERROR: wrong context'; exit 2; }
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
for outcome in projection audience-boundary; do
  set +e
  output=$(python3 "$lab_directory/testing/grade.py" "$outcome" 2>&1); status=$?
  set -e
  printf '%s\n' "$output"
  [[ "$status" == 1 && "$output" == FAIL:* ]] || exit 2
done
