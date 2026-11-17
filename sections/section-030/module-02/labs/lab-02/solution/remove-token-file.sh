#!/usr/bin/env bash
# Runs inside the control plane node container: remove the flag from the
# kube-apiserver static Pod, delete the token file and wait until the
# restarted API server rejects the old token and is ready again.
set -euo pipefail
manifest=/etc/kubernetes/manifests/kube-apiserver.yaml
token_file=$(sed -n 's/^ *- --token-auth-file=//p' "$manifest")
old_token=$(cut -d, -f1 "$token_file" | head -n 1)
sed -i '/- --token-auth-file=/d' "$manifest"
rm -f "$token_file"
for attempt in $(seq 1 60); do
  status=$(curl -sk -m 5 -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $old_token" https://127.0.0.1:6443/api || true)
  ready=$(curl -sk -m 5 https://127.0.0.1:6443/readyz || true)
  if [[ "$status" == 401 && "$ready" == ok ]]; then
    echo "The restarted API server rejects the old token and is ready (attempt $attempt)"
    exit 0
  fi
  sleep 3
done
echo 'The API server did not come back within three minutes' >&2
exit 1
