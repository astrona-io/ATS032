#!/usr/bin/env bash
# Bootstrap for lab ats-032-lab-040-01-02. astrona pipes this script into bash
# on the lab VM as the astrona account (passwordless sudo).
#
# The image (ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks-*) already has
# containerd, kubeadm/kubelet/kubectl v1.35 on hold, every v1.35 and v1.36
# control-plane image in containerd and an offline apt repository per minor
# under /opt/kubernetes-apt. This script only creates the cluster and the
# starting workload; it needs no network.

LAB_NAME=ats-032-lab-040-01-02
NODE=controlplane
NAMESPACE=starfleet-032-040-01-02

kube() {
  sudo -n kubectl --kubeconfig /etc/kubernetes/admin.conf "$@"
}

main() {
  set -euo pipefail

  # Context guard: run only on a VM built from the kubeadm image.
  if [ ! -x /usr/local/sbin/astrona-kubeadm-init ] || [ ! -r /etc/astrona-kubeadm/versions.env ]; then
    echo "Refusing to run: this VM is not built from the CKS practice image" >&2
    exit 1
  fi
  # shellcheck disable=SC1091
  . /etc/astrona-kubeadm/versions.env

  local users=()
  id student >/dev/null 2>&1 && users+=(--user student)
  sudo -n /usr/local/sbin/astrona-kubeadm-init \
    --node-name "$NODE" --cluster-name "astro-$LAB_NAME" "${users[@]}" </dev/null

  local context
  context=$(kube config current-context </dev/null)
  if [ "$context" != "kubernetes-admin@astro-$LAB_NAME" ]; then
    echo "Refusing to continue on context $context" >&2
    exit 1
  fi

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
