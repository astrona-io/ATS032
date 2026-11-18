#!/usr/bin/env bash
# Bootstrap for lab ats-032-lab-030-01-02. astrona pipes this script into bash
# on the lab VM as the astrona account (passwordless sudo).
#
# The image (ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks-*) already has
# containerd, kubeadm/kubelet/kubectl v1.35 and the busybox:1.37.0 image. This
# script creates the single-node cluster, opens the kubelet API on node
# controlplane (anonymous requests on, AlwaysAllow authorization, read-only
# port 10255) and starts the Pod probe. It needs no network.

LAB_NAME=ats-032-lab-030-01-02
NODE=controlplane
NAMESPACE=starfleet-032-030-01-02
KUBELET_CONFIG=/var/lib/kubelet/config.yaml

kube() {
  sudo -n kubectl --kubeconfig /etc/kubernetes/admin.conf "$@"
}

kubelet_mode() {
  kube get --raw "/api/v1/nodes/$NODE/proxy/configz" </dev/null 2>/dev/null \
    | jq -r '.kubeletconfig.authorization.mode' 2>/dev/null
}

main() {
  set -euo pipefail

  # Context guard: run only on a VM built from the kubeadm image.
  if [ ! -x /usr/local/sbin/astrona-kubeadm-init ] || [ ! -r /etc/astrona-kubeadm/versions.env ]; then
    echo "Refusing to run: this VM is not built from the CKS practice image" >&2
    exit 1
  fi

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

  # Open the kubelet API: anonymous requests on, AlwaysAllow authorization and
  # the read-only port 10255. Every other field of the kubeadm file stays.
  sudo -n cp "$KUBELET_CONFIG" /var/lib/kubelet/config.yaml.kubeadm
  sudo -n awk '
    /^  anonymous:$/ { print; in_anonymous = 1; next }
    in_anonymous && /^    enabled:/ { print "    enabled: true"; in_anonymous = 0; next }
    /^  mode: Webhook$/ { print "  mode: AlwaysAllow"; next }
    /^readOnlyPort:/ { next }
    { print }
    END { print "readOnlyPort: 10255" }
  ' /var/lib/kubelet/config.yaml.kubeadm | sudo -n tee "$KUBELET_CONFIG" >/dev/null
  sudo -n rm -f /var/lib/kubelet/config.yaml.kubeadm
  sudo -n systemctl restart kubelet

  local attempt
  for attempt in $(seq 1 60); do
    [ "$(kubelet_mode)" = "AlwaysAllow" ] && break
    if [ "$attempt" = 60 ]; then
      echo "The kubelet did not come back with the open configuration within three minutes" >&2
      exit 1
    fi
    sleep 3
  done
  kube wait --for=condition=Ready "node/$NODE" --timeout=120s </dev/null

  # The Pod whose logs must still work after the change. busybox:1.37.0 is
  # already in containerd, so nothing is pulled.
  kube apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
---
apiVersion: v1
kind: Pod
metadata:
  name: probe
  namespace: $NAMESPACE
  labels:
    app: probe
spec:
  containers:
  - name: probe
    image: docker.io/library/busybox:1.37.0
    imagePullPolicy: IfNotPresent
    command:
    - sh
    - -c
    - echo probe started; sleep 86400
    resources:
      requests:
        cpu: 10m
        memory: 16Mi
      limits:
        memory: 32Mi
EOF
  kube -n "$NAMESPACE" wait --for=condition=Ready pod/probe --timeout=180s </dev/null

  # Leave the student a shell that knows the cluster.
  if id student >/dev/null 2>&1; then
    echo 'source <(kubectl completion bash)' | sudo -n tee /etc/profile.d/kubectl-completion.sh >/dev/null
  fi

  kube get nodes -o wide </dev/null
}

main "$@"
