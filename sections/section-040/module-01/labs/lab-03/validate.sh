#!/usr/bin/env bash
# Shared checks for lab ats-032-lab-040-01-03 (etcd snapshot before an upgrade).
#
# This is a QEMU lab: astrona pipes each grader into `bash` on the VM over
# SSH, as the `astrona` account, with no other lab file next to it. So every
# script in validation/ and testing/ must be self-contained. This file is the
# single source of the check logic; testing/render-graders.sh copies it into
# validation/validate-<outcome>.sh, testing/verify-start.sh and
# testing/wait-solved.sh. Edit this file, then run the renderer.
#
# Run by hand on the VM: bash validate.sh [snapshot-saved|snapshot-recorded]
# Each outcome prints one PASS: or FAIL: line and exits 0 or 1.

# >>> shared checks >>>
LAB_NAME=ats-032-lab-040-01-03
LAB_CONTEXT="kubernetes-admin@astro-$LAB_NAME"
NAMESPACE=starfleet-032-040-01-03
SNAPSHOT=/var/lib/etcd/backup/pre-upgrade.db
OUTCOMES="snapshot-saved snapshot-recorded"

kube() {
  sudo -n kubectl --kubeconfig /etc/kubernetes/admin.conf --request-timeout=15s "$@" </dev/null
}

# Context guard: the graders only read this VM's own cluster.
lab_guard() {
  local context
  if [ ! -r /etc/kubernetes/admin.conf ] && ! sudo -n test -r /etc/kubernetes/admin.conf; then
    echo "FAIL: guard: /etc/kubernetes/admin.conf is missing, so this is not the lab VM or kubeadm init did not run"
    return 1
  fi
  context=$(kube config current-context 2>/dev/null) || context=""
  if [ "$context" != "$LAB_CONTEXT" ]; then
    echo "FAIL: guard: admin.conf context is '$context', expected '$LAB_CONTEXT'"
    return 1
  fi
}

# Prints the JSON status line of the snapshot file, read with etcdutl on the
# node, or nothing when the file is missing or not a snapshot.
snapshot_status() {
  sudo -n test -f "$SNAPSHOT" || return 1
  sudo -n etcdutl snapshot status "$SNAPSHOT" --write-out=json 2>/dev/null | grep '^{' | tail -n1
}

check_snapshot_saved() {
  local status hash keys size revision ticket
  status=$(snapshot_status) || status=""
  if [ -z "$status" ]; then
    echo "FAIL: snapshot-saved: no readable etcd snapshot at $SNAPSHOT"
    return 1
  fi
  hash=$(jq -r '.hash // 0' <<<"$status")
  keys=$(jq -r '.totalKey // 0' <<<"$status")
  size=$(jq -r '.totalSize // 0' <<<"$status")
  revision=$(jq -r '.revision // 0' <<<"$status")
  if [ "$hash" = "0" ] || [ "$keys" -le 0 ] || [ "$size" -le 0 ]; then
    echo "FAIL: snapshot-saved: the snapshot at $SNAPSHOT is empty or has no hash"
    return 1
  fi
  ticket=$(kube -n "$NAMESPACE" get configmap upgrade-ticket -o jsonpath='{.metadata.resourceVersion}' 2>/dev/null) || ticket=""
  if [ -z "$ticket" ]; then
    echo "FAIL: snapshot-saved: ConfigMap upgrade-ticket in $NAMESPACE is missing, so the snapshot age cannot be checked"
    return 1
  fi
  if [ "$revision" -lt "$ticket" ]; then
    echo "FAIL: snapshot-saved: the snapshot (revision $revision) is older than the lab start (revision $ticket); take a new one"
    return 1
  fi
  echo "PASS: snapshot-saved: $SNAPSHOT is an etcd snapshot at revision $revision with $keys keys"
}

check_snapshot_recorded() {
  local status revision recorded
  status=$(snapshot_status) || status=""
  if [ -z "$status" ]; then
    echo "FAIL: snapshot-recorded: no readable etcd snapshot at $SNAPSHOT"
    return 1
  fi
  revision=$(jq -r '.revision' <<<"$status")
  if ! kube -n "$NAMESPACE" get configmap snapshot-record >/dev/null 2>&1; then
    echo "FAIL: snapshot-recorded: create the ConfigMap snapshot-record in $NAMESPACE"
    return 1
  fi
  recorded=$(kube -n "$NAMESPACE" get configmap snapshot-record -o jsonpath='{.data.revision}' 2>/dev/null | tr -d '[:space:]')
  if [ "$recorded" != "$revision" ]; then
    echo "FAIL: snapshot-recorded: ConfigMap snapshot-record has revision '$recorded', but etcdutl snapshot status reports $revision for $SNAPSHOT"
    return 1
  fi
  echo "PASS: snapshot-recorded: ConfigMap snapshot-record holds revision $revision"
}

grade() {
  lab_guard || return 1
  case "$1" in
    snapshot-saved) check_snapshot_saved ;;
    snapshot-recorded) check_snapshot_recorded ;;
    *) echo "FAIL: Unknown outcome '$1'"; return 1 ;;
  esac
}
# <<< shared checks <<<

main() {
  local outcome status=0
  if [ $# -gt 0 ]; then
    grade "$1"
    return
  fi
  for outcome in $OUTCOMES; do
    grade "$outcome" || status=1
  done
  return "$status"
}

main "$@"
