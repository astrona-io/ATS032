#!/usr/bin/env bash
# Reference solution for lab ats-032-lab-040-03-03, run by `astrona test`.
# vm/apply-solution.sh runs it inside the lab VM as the VM administrator user.
# It follows solution.md: restore the snapshot into /var/lib/etcd-restore, then
# point the etcd-data hostPath of the etcd static Pod at it. Every step is safe
# to run again: an existing restore and an already edited manifest are kept.

LAB_NAME=ats-032-lab-040-03-03
SNAPSHOT=/var/backups/etcd/nightly.db
RESTORE_DIR=/var/lib/etcd-restore
MANIFEST=/etc/kubernetes/manifests/etcd.yaml

kube() {
  sudo -n kubectl --kubeconfig /etc/kubernetes/admin.conf "$@" </dev/null
}

etcd_healthy() {
  sudo -n etcdctl --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    --command-timeout=5s endpoint health >/dev/null 2>&1
}

main() {
  set -euo pipefail

  # Context guard: run only against this VM's own cluster.
  local context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-$LAB_NAME}"
  if [ "$(kubectl config current-context)" != "$context" ]; then
    echo "Refusing to operate on another Kubernetes context" >&2
    exit 1
  fi

  if sudo -n test -f "$RESTORE_DIR/member/snap/db"; then
    echo "$RESTORE_DIR already holds a restored data directory"
  else
    sudo -n etcdutl snapshot restore "$SNAPSHOT" --data-dir "$RESTORE_DIR" \
      --bump-revision 1000000000 --mark-compacted
  fi

  if sudo -n grep -q "^ *path: $RESTORE_DIR\$" "$MANIFEST"; then
    echo "$MANIFEST already mounts $RESTORE_DIR"
  else
    sudo -n sed -i "s#^\( *path: \)/var/lib/etcd\$#\1$RESTORE_DIR#" "$MANIFEST"
  fi
  sudo -n grep -n "path: $RESTORE_DIR" "$MANIFEST"

  # The kubelet notices the changed manifest and starts a new etcd container.
  local attempt
  for attempt in $(seq 1 60); do
    sleep 5
    if etcd_healthy && kube get --raw /readyz >/dev/null 2>&1; then
      echo "etcd and the API server answer (attempt $attempt)"
      return 0
    fi
  done
  echo "etcd or the API server did not become healthy" >&2
  exit 1
}

main "$@"
