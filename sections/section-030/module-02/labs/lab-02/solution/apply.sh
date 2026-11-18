#!/usr/bin/env bash
# Reference solution for lab ats-032-lab-030-02-02, run by `astrona test`.
# astrona pipes it into bash on the lab VM as the astrona account. It follows
# the same steps as solution.md: back up the manifest outside the manifests
# directory, remove --token-auth-file, delete the token file and wait until
# the restarted API server rejects the old token and is ready.

LAB_NAME=ats-032-lab-030-02-02
MANIFEST=/etc/kubernetes/manifests/kube-apiserver.yaml

kube() {
  sudo -n kubectl --kubeconfig /etc/kubernetes/admin.conf --request-timeout=10s "$@" </dev/null
}

main() {
  set -euo pipefail

  local context
  context=$(kube config current-context)
  if [ "$context" != "kubernetes-admin@astro-$LAB_NAME" ]; then
    echo "Refusing to operate on context $context" >&2
    exit 1
  fi

  local token_file old_token
  token_file=$(sudo -n sed -n 's/^ *- --token-auth-file=//p' "$MANIFEST")
  [ -n "$token_file" ] || { echo "the manifest sets no --token-auth-file" >&2; exit 1; }
  old_token=$(sudo -n cut -d, -f1 "$token_file" | head -n 1)

  sudo -n cp "$MANIFEST" /root/kube-apiserver.yaml.bak
  sudo -n sed -i '/- --token-auth-file=/d' "$MANIFEST"
  sudo -n rm -f "$token_file"

  local attempt status ready
  for attempt in $(seq 1 60); do
    status=$(curl -sk -m 5 -o /dev/null -w '%{http_code}' \
      -H "Authorization: Bearer $old_token" https://127.0.0.1:6443/api 2>/dev/null) || true
    ready=$(kube get --raw /readyz 2>/dev/null) || ready=""
    if [ "$status" = 401 ] && [ "$ready" = ok ]; then
      echo "The restarted API server rejects the old token and is ready (attempt $attempt)"
      return 0
    fi
    sleep 5
  done
  echo "The API server did not come back within five minutes" >&2
  exit 1
}

main "$@"
