#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-032-playground-020-03" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
api_server=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > "$work/ca.crt"
token=$(kubectl -n outpost create token archive --duration=10m)
identity=$(kubectl --kubeconfig=/dev/null --server="$api_server" --certificate-authority="$work/ca.crt" --token="$token" auth whoami -o jsonpath='{.status.userInfo.username}')
[[ "$identity" == system:serviceaccount:outpost:archive ]]
token=$(kubectl -n outpost create token archive --audience=ledger --duration=10m)
if kubectl --kubeconfig=/dev/null --server="$api_server" --certificate-authority="$work/ca.crt" --token="$token" auth whoami > "$work/rejected" 2>&1; then
  echo 'Wrong-audience token unexpectedly authenticated' >&2
  exit 1
fi
grep -qi 'unauthorized\|provide credentials' "$work/rejected"
unset token
printf 'PASS: isolated token identity and audience rejection\n'
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
if bash "$lab_directory/validate.sh"; then
  printf 'Starting state unexpectedly passes grading\n' >&2
  exit 1
fi
bash "$lab_directory/solution/apply.sh"
for attempt in $(seq 1 20); do
  if bash "$lab_directory/validate.sh"; then exit 0; fi
  sleep 3
done
printf 'Reference result did not pass within the bounded retry period\n' >&2
exit 1
