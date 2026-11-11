#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-030-03-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-030-03-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
[[ "$(kubectl config current-context)" == "$context" ]] || { echo 'ERROR: wrong context'; exit 2; }
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl patch validatingwebhookconfiguration training-guard --type=json -p '[{"op": "replace", "path": "/webhooks/0/failurePolicy", "value": "Fail"}, {"op": "replace", "path": "/webhooks/0/namespaceSelector", "value": {"matchLabels": {"admission.training/protected": "true"}}}, {"op": "replace", "path": "/webhooks/0/timeoutSeconds", "value": 2}]'
