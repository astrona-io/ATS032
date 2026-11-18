#!/usr/bin/env bash
# Shared checks for lab ats-032-lab-040-01-02 (kubeadm control-plane upgrade).
#
# This is a QEMU lab: astrona pipes each grader into `bash` on the VM over
# SSH, as the `astrona` account, with no other lab file next to it. So every
# script in validation/ and testing/ must be self-contained. This file is the
# single source of the check logic; testing/render-graders.sh copies it into
# validation/validate-<outcome>.sh, testing/verify-start.sh and
# testing/wait-solved.sh. Edit this file, then run the renderer.
#
# Run by hand on the VM: bash validate.sh [control-plane-upgraded|packages-held|node-uncordoned]
# Each outcome prints one PASS: or FAIL: line and exits 0 or 1.

# >>> shared checks >>>
LAB_NAME=ats-032-lab-040-01-02
LAB_CONTEXT="kubernetes-admin@astro-$LAB_NAME"
NODE=controlplane
NAMESPACE=starfleet-032-040-01-02
TARGET_MINOR=1.36
OUTCOMES="control-plane-upgraded packages-held node-uncordoned"

kube() {
  sudo -n kubectl --kubeconfig /etc/kubernetes/admin.conf --request-timeout=15s "$@" </dev/null
}

on_target_minor() {
  # Accepts v1.36.N, 1.36.N and Debian versions such as 1.36.N-1.1.
  [[ "${1#v}" == "$TARGET_MINOR".* ]]
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

check_control_plane_upgraded() {
  local server component pod image ready proxy config_version
  server=$(kube version -o json 2>/dev/null | jq -r '.serverVersion.gitVersion // empty') || server=""
  if ! on_target_minor "$server"; then
    echo "FAIL: control-plane-upgraded: the API server reports '${server:-no answer}', expected v$TARGET_MINOR.x"
    return 1
  fi
  for component in kube-apiserver kube-controller-manager kube-scheduler; do
    pod=$(kube -n kube-system get pods -l "component=$component" \
      --field-selector "spec.nodeName=$NODE" -o json 2>/dev/null) || pod='{"items":[]}'
    image=$(jq -r '.items[0].spec.containers[0].image // empty' <<<"$pod")
    ready=$(jq -r '.items[0].status.conditions[]? | select(.type=="Ready") | .status' <<<"$pod")
    if ! on_target_minor "${image##*:}"; then
      echo "FAIL: control-plane-upgraded: static Pod $component runs image '${image:-none}', expected tag v$TARGET_MINOR.x"
      return 1
    fi
    if [ "$ready" != "True" ]; then
      echo "FAIL: control-plane-upgraded: static Pod $component on $NODE is not Ready"
      return 1
    fi
  done
  proxy=$(kube -n kube-system get daemonset kube-proxy \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null) || proxy=""
  if ! on_target_minor "${proxy##*:}"; then
    echo "FAIL: control-plane-upgraded: DaemonSet kube-proxy uses image '${proxy:-none}', expected tag v$TARGET_MINOR.x"
    return 1
  fi
  config_version=$(kube -n kube-system get configmap kubeadm-config \
    -o jsonpath='{.data.ClusterConfiguration}' 2>/dev/null | sed -n 's/^kubernetesVersion: *//p') || config_version=""
  if ! on_target_minor "$config_version"; then
    echo "FAIL: control-plane-upgraded: ConfigMap kubeadm-config records kubernetesVersion '${config_version:-none}', expected v$TARGET_MINOR.x"
    return 1
  fi
  echo "PASS: control-plane-upgraded: API server $server; kube-apiserver, kube-controller-manager, kube-scheduler and kube-proxy run v$TARGET_MINOR images"
}

check_packages_held() {
  local package version held
  held=$(apt-mark showhold 2>/dev/null)
  for package in kubeadm kubelet kubectl; do
    version=$(dpkg-query -W -f='${Version}' "$package" 2>/dev/null) || version=""
    if ! on_target_minor "$version"; then
      echo "FAIL: packages-held: package $package is at '${version:-not installed}', expected $TARGET_MINOR.x"
      return 1
    fi
    if ! grep -qx "$package" <<<"$held"; then
      echo "FAIL: packages-held: package $package ($version) is not on hold (apt-mark showhold)"
      return 1
    fi
  done
  echo "PASS: packages-held: kubeadm, kubelet and kubectl are at $TARGET_MINOR.x and on hold"
}

check_node_uncordoned() {
  local node unschedulable ready kubelet desired available
  node=$(kube get node "$NODE" -o json 2>/dev/null) || node=""
  if [ -z "$node" ]; then
    echo "FAIL: node-uncordoned: node $NODE is not readable"
    return 1
  fi
  kubelet=$(jq -r '.status.nodeInfo.kubeletVersion' <<<"$node")
  if ! on_target_minor "$kubelet"; then
    echo "FAIL: node-uncordoned: node $NODE reports kubelet '$kubelet', expected v$TARGET_MINOR.x (restart the kubelet after the package upgrade)"
    return 1
  fi
  unschedulable=$(jq -r '.spec.unschedulable // false' <<<"$node")
  if [ "$unschedulable" = "true" ]; then
    echo "FAIL: node-uncordoned: node $NODE is still cordoned (SchedulingDisabled)"
    return 1
  fi
  ready=$(jq -r '.status.conditions[] | select(.type=="Ready") | .status' <<<"$node")
  if [ "$ready" != "True" ]; then
    echo "FAIL: node-uncordoned: node $NODE is not Ready"
    return 1
  fi
  desired=$(kube -n "$NAMESPACE" get deployment probe -o jsonpath='{.spec.replicas}' 2>/dev/null) || desired=""
  available=$(kube -n "$NAMESPACE" get deployment probe -o jsonpath='{.status.availableReplicas}' 2>/dev/null) || available=""
  if [ -z "$desired" ] || [ "${available:-0}" != "$desired" ]; then
    echo "FAIL: node-uncordoned: Deployment probe in $NAMESPACE has ${available:-0} of ${desired:-?} replicas available"
    return 1
  fi
  echo "PASS: node-uncordoned: node $NODE is Ready and schedulable with kubelet $kubelet; Deployment probe is available"
}

grade() {
  lab_guard || return 1
  case "$1" in
    control-plane-upgraded) check_control_plane_upgraded ;;
    packages-held) check_packages_held ;;
    node-uncordoned) check_node_uncordoned ;;
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
