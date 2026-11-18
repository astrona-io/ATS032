#!/usr/bin/env bash
# Reference solution for lab ats-032-lab-040-01-02, run by `astrona test`.
# astrona pipes it into bash on the lab VM as the astrona account. It follows
# the same steps as solution.md: kubeadm first, plan and apply, then drain,
# kubelet and kubectl, restart, uncordon. Every package stays on hold.

LAB_NAME=ats-032-lab-040-01-02
NODE=controlplane
LIST=/etc/apt/sources.list.d/kubernetes.list

kube() {
  sudo -n kubectl --kubeconfig /etc/kubernetes/admin.conf "$@" </dev/null
}

# A kubelet restart briefly takes the API server static Pod down, so wait
# (at most three minutes) until it answers with authorization working.
wait_for_api() {
  local attempt
  for attempt in $(seq 1 36); do
    if kube get "node/$NODE" >/dev/null 2>&1; then
      return 0
    fi
    sleep 5
  done
  echo "the API server did not come back within three minutes" >&2
  return 1
}

main() {
  set -euo pipefail
  export DEBIAN_FRONTEND=noninteractive

  local context
  context=$(kube config current-context)
  if [ "$context" != "kubernetes-admin@astro-$LAB_NAME" ]; then
    echo "Refusing to operate on context $context" >&2
    exit 1
  fi

  # Point the Kubernetes package source at the v1.36 repository.
  sudo -n sed -i 's#/v1\.35/#/v1.36/#' "$LIST"
  sudo -n apt-get update </dev/null
  local version
  version=$(apt-cache madison kubeadm | awk '$3 ~ /^1\.36\./ {print $3; exit}')
  [ -n "$version" ] || { echo "no kubeadm 1.36 package in the repository" >&2; exit 1; }
  echo "target package version: $version"

  # 1. kubeadm
  sudo -n apt-mark unhold kubeadm
  sudo -n apt-get install -y kubeadm="$version" </dev/null
  sudo -n apt-mark hold kubeadm
  kubeadm version -o short

  # 2. Plan and apply the control-plane upgrade.
  local target
  target=$(kubeadm version -o short)
  sudo -n kubeadm upgrade plan </dev/null
  sudo -n kubeadm upgrade apply "$target" --yes </dev/null

  # 3. Drain, upgrade kubelet and kubectl, restart the kubelet, uncordon.
  kube drain "$NODE" --ignore-daemonsets --timeout=180s
  sudo -n apt-mark unhold kubelet kubectl
  sudo -n apt-get install -y kubelet="$version" kubectl="$version" </dev/null
  sudo -n apt-mark hold kubelet kubectl
  sudo -n systemctl daemon-reload
  sudo -n systemctl restart kubelet
  wait_for_api
  kube wait --for=condition=Ready "node/$NODE" --timeout=180s
  kube uncordon "$NODE"
  apt-mark showhold
}

main "$@"
