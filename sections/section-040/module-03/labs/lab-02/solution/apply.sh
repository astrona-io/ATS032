#!/usr/bin/env bash
# Reference solution for lab ats-032-lab-040-03-02, run by `astrona test`.
# vm/apply-solution.sh runs it inside the lab VM as the VM administrator user.
# It follows solution.md: drain the node, restart containerd, wait for Ready,
# uncordon. Every step is safe to run again.

LAB_NAME=ats-032-lab-040-03-02
NODE=controlplane
NAMESPACE=starfleet-032-040-03-02

kube() {
  sudo -n kubectl --kubeconfig /etc/kubernetes/admin.conf "$@" </dev/null
}

main() {
  set -euo pipefail

  # Context guard: run only against this VM's own cluster.
  local context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-$LAB_NAME}"
  if [ "$(kubectl config current-context)" != "$context" ]; then
    echo "Refusing to operate on another Kubernetes context" >&2
    exit 1
  fi

  kube drain "$NODE" --ignore-daemonsets --timeout=180s
  sudo -n systemctl restart containerd
  systemctl is-active containerd
  kube wait --for=condition=Ready "node/$NODE" --timeout=180s
  kube uncordon "$NODE"
  kube -n "$NAMESPACE" rollout status deployment/probe --timeout=180s
}

main "$@"
