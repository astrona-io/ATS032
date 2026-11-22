#!/usr/bin/env bash
# Bootstrap for lab ats-032-lab-040-03-03. vm/install.sh builds the one-node
# cluster (node controlplane) and runs this script inside the lab VM from
# /opt/astrona-lab as the VM administrator user (passwordless sudo).
#
# Start state: the nightly snapshot /var/backups/etcd/nightly.db holds the
# ConfigMap fleet-roster. After the snapshot, a bad change deleted fleet-roster
# and created the ConfigMap course-correction. The student restores the
# snapshot into a new data directory and points the etcd static Pod at it.
# etcdctl and etcdutl are copied out of the etcd image that the node already
# holds, so nothing is pulled.

LAB_NAME=ats-032-lab-040-03-03
NODE=controlplane
NAMESPACE=starfleet-032-040-03-03
SNAPSHOT=/var/backups/etcd/nightly.db
BASELINE=/etc/astrona-lab/etcd-restore.env

kube() {
  sudo -n kubectl --kubeconfig /etc/kubernetes/admin.conf "$@"
}

etcdctl_local() {
  sudo -n etcdctl --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key "$@"
}

install_etcd_tools() {
  local image work blob
  image=$(sudo -n sed -n 's/^ *image: *//p' /etc/kubernetes/manifests/etcd.yaml | head -n1)
  [ -n "$image" ] || { echo "no etcd image in /etc/kubernetes/manifests/etcd.yaml" >&2; return 1; }
  work=$(mktemp -d)
  sudo -n ctr -n k8s.io images export --local --platform "linux/$(dpkg --print-architecture)" \
    "$work/etcd-image.tar" "$image"
  mkdir -p "$work/image" "$work/files"
  sudo -n tar -xf "$work/etcd-image.tar" -C "$work/image"
  for blob in "$work"/image/blobs/sha256/*; do
    # Only the layers are gzip archives; the other blobs are JSON and are skipped.
    sudo -n tar -xzf "$blob" -C "$work/files" usr/local/bin/etcdctl usr/local/bin/etcdutl 2>/dev/null || true
  done
  sudo -n install -m 0755 "$work/files/usr/local/bin/etcdctl" "$work/files/usr/local/bin/etcdutl" /usr/local/bin/
  sudo -n rm -rf "$work"
  etcdctl version
  etcdutl version
}

main() {
  set -euo pipefail

  # Context guard: run only against this VM's own cluster.
  local context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-$LAB_NAME}"
  if [ "$(kubectl config current-context)" != "$context" ]; then
    echo "Refusing to operate on another Kubernetes context" >&2
    exit 1
  fi

  install_etcd_tools </dev/null

  kube apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: fleet-roster
  namespace: $NAMESPACE
data:
  bridge: "1"
  scout: "2"
  shuttle: "4"
EOF

  # The nightly snapshot, taken while fleet-roster exists.
  sudo -n mkdir -p /var/backups/etcd
  etcdctl_local snapshot save "$SNAPSHOT" </dev/null
  sudo -n chmod 0600 "$SNAPSHOT"

  local roster_uid
  roster_uid=$(kube -n "$NAMESPACE" get configmap fleet-roster -o jsonpath='{.metadata.uid}' </dev/null)
  sudo -n mkdir -p "$(dirname "$BASELINE")"
  printf 'roster-uid=%s\n' "$roster_uid" | sudo -n tee "$BASELINE" >/dev/null
  sudo -n chmod 0600 "$BASELINE"

  # The bad change after the snapshot.
  kube -n "$NAMESPACE" delete configmap fleet-roster </dev/null
  kube -n "$NAMESPACE" create configmap course-correction --from-literal=heading=270 </dev/null

  # Leave the student a shell that knows the cluster.
  if id student >/dev/null 2>&1; then
    echo 'source <(kubectl completion bash)' | sudo -n tee /etc/profile.d/kubectl-completion.sh >/dev/null
  fi

  kube -n "$NAMESPACE" get configmaps </dev/null
}

main "$@"
