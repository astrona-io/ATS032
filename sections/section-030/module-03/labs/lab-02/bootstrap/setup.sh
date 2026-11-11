#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-032-lab-030-03-02}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-032-lab-030-03-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
[[ "$(kubectl config current-context)" == "$context" ]] || { echo 'ERROR: wrong context'; exit 2; }
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl create namespace webhook-system
kubectl create namespace protected
kubectl create namespace ordinary
kubectl label namespace protected admission.training/protected=true
certs=$(mktemp -d)
trap 'rm -rf "$certs"' EXIT
openssl req -x509 -newkey rsa:2048 -nodes -days 2 -keyout "$certs/key" -out "$certs/cert" -subj /CN=guard.webhook-system.svc -addext 'subjectAltName=DNS:guard.webhook-system.svc' >/dev/null 2>&1
kubectl -n webhook-system create secret tls guard-tls --cert="$certs/cert" --key="$certs/key"
kubectl -n webhook-system create configmap guard-code --from-file=server.py="$lab_directory/bootstrap/server.py"
kubectl apply -f "$lab_directory/bootstrap/server.yaml"
kubectl -n webhook-system rollout status deployment/guard --timeout=180s
python3 - "$lab_directory/bootstrap/webhook.json" "$certs/cert" <<'PATCH'
import json,sys,base64,subprocess
obj=json.load(open(sys.argv[1]));obj['webhooks'][0]['clientConfig']['caBundle']=base64.b64encode(open(sys.argv[2],'rb').read()).decode()
subprocess.run(['kubectl','apply','-f','-'],input=json.dumps(obj),text=True,check=True)
PATCH
