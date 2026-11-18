#!/usr/bin/env bash
# Shared checks for lab ats-032-lab-030-02-02 (remove static token
# authentication from the API server).
#
# This is a QEMU lab: astrona pipes each grader into `bash` on the VM over
# SSH, as the `astrona` account, with no other lab file next to it. So every
# script in validation/ and testing/ must be self-contained. This file is the
# single source of the check logic; testing/render-graders.sh copies it into
# validation/validate-<outcome>.sh, testing/verify-start.sh and
# testing/wait-solved.sh. Edit this file, then run the renderer.
#
# Run by hand on the VM: bash validate.sh [apiserver-no-token-file|static-token-rejected|apiserver-ready]
# Each outcome prints one PASS: or FAIL: line and exits 0 or 1.

# >>> shared checks >>>
LAB_NAME=ats-032-lab-030-02-02
LAB_CONTEXT="kubernetes-admin@astro-$LAB_NAME"
NODE=controlplane
MANIFEST=/etc/kubernetes/manifests/kube-apiserver.yaml
TOKEN_COPY=/var/lib/ats-032-lab/legacy-token
FLAG=--token-auth-file
OUTCOMES="apiserver-no-token-file static-token-rejected apiserver-ready"

kube() {
  sudo -n kubectl --kubeconfig /etc/kubernetes/admin.conf --request-timeout=15s "$@" </dev/null
}

# Context guard: the graders only read this VM's own cluster.
lab_guard() {
  local context
  if ! sudo -n test -r /etc/kubernetes/admin.conf; then
    echo "FAIL: guard: /etc/kubernetes/admin.conf is missing, so this is not the lab VM or kubeadm init did not run"
    return 1
  fi
  context=$(kube config current-context 2>/dev/null) || context=""
  if [ "$context" != "$LAB_CONTEXT" ]; then
    echo "FAIL: guard: admin.conf context is '$context', expected '$LAB_CONTEXT'"
    return 1
  fi
  if ! sudo -n test -s "$TOKEN_COPY"; then
    echo "FAIL: guard: $TOKEN_COPY is missing; start the lab again and leave /var/lib/ats-032-lab as it is"
    return 1
  fi
}

lab_token() {
  sudo -n cat "$TOKEN_COPY"
}

check_apiserver_no_token_file() {
  local token leftover
  if sudo -n grep -q -- "$FLAG" "$MANIFEST"; then
    echo "FAIL: apiserver-no-token-file: $MANIFEST still sets $FLAG"
    return 1
  fi
  token=$(lab_token)
  leftover=$(sudo -n grep -rlF -- "$token" /etc/kubernetes 2>/dev/null | tr '\n' ' ')
  if [ -n "$leftover" ]; then
    echo "FAIL: apiserver-no-token-file: delete the static token file: $leftover"
    return 1
  fi
  echo "PASS: apiserver-no-token-file: $MANIFEST has no $FLAG and no file under /etc/kubernetes holds the old token"
}

check_static_token_rejected() {
  local token status
  token=$(lab_token)
  status=$(curl -sk -m 5 -o /dev/null -w '%{http_code}' \
    -H "Authorization: Bearer $token" https://127.0.0.1:6443/api 2>/dev/null) || true
  if [ "$status" != "401" ]; then
    echo "FAIL: static-token-rejected: a request with the old static token must return 401, got ${status:-no answer}"
    return 1
  fi
  echo "PASS: static-token-rejected: a request with the old static token returns 401"
}

check_apiserver_ready() {
  local pod arguments ready readyz
  pod=$(kube -n kube-system get pod "kube-apiserver-$NODE" -o json 2>/dev/null) || pod=""
  if [ -z "$pod" ]; then
    echo "FAIL: apiserver-ready: the Pod kube-apiserver-$NODE is not readable (is the API server running?)"
    return 1
  fi
  arguments=$(jq -r '.spec.containers[0] | ((.command // []) + (.args // []))[]' <<<"$pod")
  if grep -q -- "^$FLAG" <<<"$arguments"; then
    echo "FAIL: apiserver-ready: the running kube-apiserver still uses $FLAG"
    return 1
  fi
  ready=$(jq -r '.status.conditions[]? | select(.type=="Ready") | .status' <<<"$pod")
  if [ "$ready" != "True" ]; then
    echo "FAIL: apiserver-ready: the Pod kube-apiserver-$NODE is not Ready"
    return 1
  fi
  readyz=$(kube get --raw /readyz 2>/dev/null) || readyz=""
  if [ "$readyz" != "ok" ]; then
    echo "FAIL: apiserver-ready: the API server must answer /readyz with ok, got '${readyz:-no answer}'"
    return 1
  fi
  echo "PASS: apiserver-ready: the Pod kube-apiserver-$NODE is Ready without $FLAG and /readyz is ok"
}

grade() {
  lab_guard || return 1
  case "$1" in
    apiserver-no-token-file) check_apiserver_no_token_file ;;
    static-token-rejected) check_static_token_rejected ;;
    apiserver-ready) check_apiserver_ready ;;
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
