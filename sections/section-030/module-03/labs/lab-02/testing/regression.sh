#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-030-03-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-030-03-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
[[ "$(kubectl config current-context)" == "$context" ]] || { echo 'ERROR: wrong context'; exit 2; }
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
for outcome in healthy-policy unavailable-policy; do python3 "$lab_directory/testing/grade.py" "$outcome"; done
kubectl patch validatingwebhookconfiguration training-guard --type=json -p '[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Ignore"}]'
set +e
output=$(python3 "$lab_directory/testing/grade.py" unavailable-policy); status=$?
set -e
[[ "$status" == 1 && "$output" == 'FAIL: Set failurePolicy to Fail' ]]
bash "$lab_directory/solution/apply.sh"
