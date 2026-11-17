#!/usr/bin/env bash
# Runs inside the control plane node container: set the authorization modes
# back to Node,RBAC and wait until the restarted API server refuses a user
# without RBAC rules and is ready.
set -euo pipefail
manifest=/etc/kubernetes/manifests/kube-apiserver.yaml
admin=(kubectl --kubeconfig /etc/kubernetes/admin.conf --request-timeout=5s)
sed -i 's/^\( *- --authorization-mode=\).*$/\1Node,RBAC/' "$manifest"
for attempt in $(seq 1 60); do
  answer=$("${admin[@]}" auth can-i list secrets -n kube-system --as=nobody 2>/dev/null || true)
  ready=$("${admin[@]}" get --raw /readyz 2>/dev/null || true)
  if [[ "$answer" == no && "$ready" == ok ]]; then
    echo "The API server runs with Node,RBAC (attempt $attempt)"
    exit 0
  fi
  sleep 3
done
echo 'The API server did not come back within three minutes' >&2
exit 1
