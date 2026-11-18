#!/usr/bin/env bash
# Reference solution for lab ats-032-lab-040-01-03, run by `astrona test`.
# astrona pipes it into bash on the lab VM as the astrona account. It follows
# the same steps as solution.md: create the backup directory, save the
# snapshot with etcdctl, read its revision with etcdutl and record it in the
# ConfigMap snapshot-record.

LAB_NAME=ats-032-lab-040-01-03
NAMESPACE=starfleet-032-040-01-03
SNAPSHOT=/var/lib/etcd/backup/pre-upgrade.db

kube() {
  sudo -n kubectl --kubeconfig /etc/kubernetes/admin.conf "$@" </dev/null
}

main() {
  set -euo pipefail

  local context
  context=$(kube config current-context)
  if [ "$context" != "kubernetes-admin@astro-$LAB_NAME" ]; then
    echo "Refusing to operate on context $context" >&2
    exit 1
  fi

  sudo -n mkdir -p -m 0700 /var/lib/etcd/backup
  sudo -n etcdctl \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    snapshot save "$SNAPSHOT" </dev/null

  local revision
  revision=$(sudo -n etcdutl snapshot status "$SNAPSHOT" --write-out=json </dev/null | grep '^{' | tail -n1 | jq -r '.revision')
  echo "snapshot revision: $revision"
  kube -n "$NAMESPACE" create configmap snapshot-record \
    --from-literal=revision="$revision" --dry-run=client -o yaml | \
    sudo -n kubectl --kubeconfig /etc/kubernetes/admin.conf apply -f -
}

main "$@"
