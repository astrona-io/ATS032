#!/usr/bin/env bash
# Bootstrap for lab ats-032-lab-040-01-02. vm/install.sh builds the one-node
# cluster (node controlplane) and runs this script inside the lab VM from
# /opt/astrona-lab as the VM administrator user (passwordless sudo).
#
# The image (ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks-*) already has
# containerd, kubeadm/kubelet/kubectl v1.35 on hold, every v1.35 and v1.36
# control-plane image in containerd and an offline apt repository per minor
# under /opt/kubernetes-apt. This script only creates the starting workload; it
# needs no network.

LAB_NAME=ats-032-lab-040-01-02
NODE=controlplane
NAMESPACE=starfleet-032-040-01-02

kube() {
  sudo -n kubectl --kubeconfig /etc/kubernetes/admin.conf "$@"
}

main() {
  set -euo pipefail

  # Context guard: run only against this VM's own cluster.
  local context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-$LAB_NAME}"
  if [ "$(kubectl config current-context)" != "$context" ]; then
    echo "Refusing to operate on another Kubernetes context" >&2
    exit 1
  fi
  # shellcheck disable=SC1091
  . /etc/astrona-kubeadm/versions.env

  # The workload that the drain moves. It uses the pause image, which is
  # already in containerd, so nothing is pulled.
  kube apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: probe
  namespace: $NAMESPACE
spec:
  replicas: 2
  selector:
    matchLabels:
      app: probe
  template:
    metadata:
      labels:
        app: probe
    spec:
      containers:
      - name: probe
        image: $PAUSE_IMAGE
        imagePullPolicy: IfNotPresent
EOF
  kube -n "$NAMESPACE" rollout status deployment/probe --timeout=180s </dev/null

  # Leave the student a shell that knows the cluster.
  if id student >/dev/null 2>&1; then
    echo 'source <(kubectl completion bash)' | sudo -n tee /etc/profile.d/kubectl-completion.sh >/dev/null
  fi

  kube get nodes -o wide </dev/null
}

main "$@"
