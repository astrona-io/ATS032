#!/usr/bin/env bash
# Runs inside the control plane node container. Writes a static token file
# with one random token for a system:masters user, adds --token-auth-file to
# the kube-apiserver static Pod and waits until the restarted API server
# accepts the token. The grader keeps its own copy of the token outside the
# Kubernetes directories.
set -euo pipefail
manifest=/etc/kubernetes/manifests/kube-apiserver.yaml
token_file=/etc/kubernetes/pki/legacy-tokens.csv
mkdir -p /var/lib/ats-032-lab
token=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
printf '%s,legacy-admin,legacy-admin-uid,"system:masters"\n' "$token" > "$token_file"
chmod 600 "$token_file"
printf '%s' "$token" > /var/lib/ats-032-lab/legacy-token
if ! grep -q -- '--token-auth-file=' "$manifest"; then
  sed -i "/- --authorization-mode=/a\\    - --token-auth-file=$token_file" "$manifest"
fi
for attempt in $(seq 1 60); do
  status=$(curl -sk -m 5 -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $token" https://127.0.0.1:6443/api || true)
  if [[ "$status" == 200 ]]; then
    echo "The API server accepts the static token (attempt $attempt)"
    exit 0
  fi
  sleep 3
done
echo 'The API server did not come back with the static token file within three minutes' >&2
exit 1
