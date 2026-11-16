#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-020-01-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-020-01-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
[[ "$(kubectl config current-context)" == "$context" ]] || { echo 'ERROR: wrong context'; exit 2; }
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
for outcome in projection audience-boundary; do python3 "$lab_directory/testing/grade.py" "$outcome"; done
kubectl -n audience-training delete pod reporter --wait=true
kubectl apply -f "$lab_directory/bootstrap/pod.yaml"
kubectl -n audience-training wait --for=condition=Ready pod/reporter --timeout=180s
set +e
output=$(python3 "$lab_directory/testing/grade.py" audience-boundary); status=$?
set -e
[[ "$status" == 1 && "$output" == 'FAIL: Project a 600-second telemetry.training token' ]]
bash "$lab_directory/solution/apply.sh"
