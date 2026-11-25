#!/usr/bin/env bash
# Reference solution for lab ats-032-lab-030-01-02, run by `astrona test`.
# vm/apply-solution.sh runs it inside the lab VM as the VM administrator user.
# It follows the same steps as solution.md: anonymous requests off, Webhook
# authorization, read-only port off, restart the kubelet, wait for the node.

LAB_NAME=ats-032-lab-030-01-02
NODE=controlplane
KUBELET_CONFIG=/var/lib/kubelet/config.yaml

kube() {
  sudo -n kubectl --kubeconfig /etc/kubernetes/admin.conf "$@" </dev/null
}

kubelet_mode() {
  kube get --raw "/api/v1/nodes/$NODE/proxy/configz" 2>/dev/null \
    | jq -r '.kubeletconfig.authorization.mode' 2>/dev/null
}

main() {
  set -euo pipefail

  # Context guard: run only against this VM's own cluster.
  local context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-$LAB_NAME}"
  if [ "$(kubectl config current-context)" != "$context" ]; then
    echo "Refusing to operate on another Kubernetes context" >&2
    exit 1
  fi

  sudo -n sed -i \
    -e '/^  anonymous:$/{n;s/enabled: true/enabled: false/}' \
    -e 's/^  mode: AlwaysAllow$/  mode: Webhook/' \
    -e 's/^readOnlyPort: .*/readOnlyPort: 0/' \
    "$KUBELET_CONFIG"
  sudo -n systemctl restart kubelet

  local attempt
  for attempt in $(seq 1 60); do
    [ "$(kubelet_mode)" = "Webhook" ] && break
    if [ "$attempt" = 60 ]; then
      echo "The kubelet did not come back with Webhook authorization within three minutes" >&2
      exit 1
    fi
    sleep 3
  done
  kube wait --for=condition=Ready "node/$NODE" --timeout=120s
}

main "$@"
