#!/usr/bin/env bash
# Runs inside the control plane node container. Appends AlwaysAllow to the
# authorization modes of the kube-apiserver static Pod and waits until the
# restarted API server authorizes a user without RBAC rules.
#
# With AlwaysAllow the API server turns anonymous authentication off
# ("AnonymousAuth is not allowed with the AlwaysAllow authorizer"), so the
# kubelet's anonymous HTTPS probes get 401 and the Pod never becomes ready.
# The probes are changed to TCP checks on the same port so that the API
# server keeps running in this start state.
set -euo pipefail
manifest=/etc/kubernetes/manifests/kube-apiserver.yaml
admin=(kubectl --kubeconfig /etc/kubernetes/admin.conf --request-timeout=5s)
if ! grep -q -- '--authorization-mode=.*AlwaysAllow' "$manifest"; then
  sed -i \
    -e 's/^\( *- --authorization-mode=.*\)$/\1,AlwaysAllow/' \
    -e '/httpGet:/,/scheme: HTTPS/{s/httpGet:/tcpSocket:/;/path:/d;/scheme:/d}' \
    "$manifest"
fi
for attempt in $(seq 1 60); do
  answer=$("${admin[@]}" auth can-i list secrets -n kube-system --as=nobody 2>/dev/null || true)
  ready=$("${admin[@]}" get --raw /readyz 2>/dev/null || true)
  if [[ "$answer" == yes && "$ready" == ok ]]; then
    echo "The API server runs with AlwaysAllow (attempt $attempt)"
    exit 0
  fi
  sleep 3
done
echo 'The API server did not come back within three minutes' >&2
exit 1
