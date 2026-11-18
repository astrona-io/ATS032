#!/usr/bin/env bash
# Bootstrap for lab ats-032-lab-040-01-03. astrona pipes this script into bash
# on the lab VM as the astrona account (passwordless sudo).
#
# The image (ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks-*) already has
# containerd, kubeadm/kubelet/kubectl v1.35 and every control-plane image in
# containerd. This script creates the cluster, copies etcdctl and etcdutl out
# of the etcd image into /usr/local/bin, and creates the namespace and the
# ConfigMap upgrade-ticket. The grader checks that the snapshot is newer than
# that ConfigMap, so a snapshot from an earlier start cannot pass. It needs no
# network.

LAB_NAME=ats-032-lab-040-01-03
NODE=controlplane
NAMESPACE=starfleet-032-040-01-03

kube() {
  sudo -n kubectl --kubeconfig /etc/kubernetes/admin.conf "$@"
}

# Copy etcdctl and etcdutl into /usr/local/bin from the etcd image that
# kubeadm already runs. The root file system of the running etcd container is
# that image, so nothing is pulled.
install_etcd_tools() {
  local container rootfs tool
  container=$(sudo -n crictl ps --name '^etcd$' --state Running -q | head -n1)
  [ -n "$container" ] || { echo "no running etcd container" >&2; return 1; }
  rootfs="/run/containerd/io.containerd.runtime.v2.task/k8s.io/$container/rootfs"
  for tool in etcdctl etcdutl; do
    sudo -n install -m 0755 "$rootfs/usr/local/bin/$tool" "/usr/local/bin/$tool"
  done
  etcdctl version
  etcdutl version
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

  install_etcd_tools </dev/null
  sudo -n rm -rf /var/lib/etcd/backup

  kube create namespace "$NAMESPACE" --dry-run=client -o yaml </dev/null | kube apply -f -
  kube -n "$NAMESPACE" create configmap upgrade-ticket \
    --from-literal=ticket="CHG-$((RANDOM % 9000 + 1000))" \
    --dry-run=client -o yaml </dev/null | kube apply -f -
  kube -n kube-system wait --for=condition=Ready pod -l component=etcd --timeout=120s </dev/null

  # Leave the student a shell that knows the cluster.
  if id student >/dev/null 2>&1; then
    echo 'source <(kubectl completion bash)' | sudo -n tee /etc/profile.d/kubectl-completion.sh >/dev/null
  fi

  kube get nodes -o wide </dev/null
}

main "$@"
