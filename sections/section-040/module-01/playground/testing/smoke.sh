#!/usr/bin/env bash
# Runs the commands that the module pages and the playground guide teach inside
# the playground VM and fails when one of them does not give the result the
# page describes. Every command is first looked up on its page and then run
# exactly as the page writes it, and every YAML file comes from the page, so
# the pages and this test cannot drift apart.
# scripts/ci/test-playground.sh copies the pages and this folder into the VM
# and runs the script there as the student user. The VM is the only node, so
# node commands use sudo directly.
#
# The pages build on each other: the guide and the first page read the
# starting state at 1.35, the second page drains the node, the third upgrades
# the cluster to 1.36 (this cannot be undone) and the fourth takes an etcd
# snapshot on the upgraded cluster. The script runs them in that order.
set -euo pipefail
# Keep set -e inside $(...), so a failed page lookup also stops a captured command.
shopt -s inherit_errexit 2>/dev/null || true
cluster_name=astro-ats-032-playground-040-01
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@$cluster_name}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
# The pages save files in the current folder, so work in an empty one.
cd "$work_directory"

# Fail unless the page has this exact command in one of its ```sh blocks.
on_page() {
  python3 - "$module_directory/$1" "$2" <<'PY'
import re, sys
page, command = sys.argv[1:]
blocks = re.findall(r'```sh\n(.*?)```', open(page).read(), re.S)
if not any(command in block for block in blocks):
    sys.exit('the page ' + page + ' has no command: ' + command)
PY
}

# Run a command exactly as the page writes it.
page_run() {
  on_page "$1" "$2" || exit 1
  printf '$ %s\n' "$2" >&2
  eval "$2"
}

# Run a command that the page says must fail, and print its output.
page_fails() {
  local output
  on_page "$1" "$2" || exit 1
  printf '$ %s\n' "$2" >&2
  if output="$(eval "$2" 2>&1)"; then
    printf 'FAIL: the command succeeded, the page says it fails: %s\n%s\n' "$2" "$output" >&2
    exit 1
  fi
  printf '%s\n' "$output"
}

# Print a phrase that the page states, and fail when the page no longer has it.
# A check uses it for the output the page promises, so a page edit that changes
# the promise also changes the check.
text_from_page() {
  python3 - "$module_directory/$1" "$2" <<'PY'
import sys
page, phrase = sys.argv[1:]
if ' '.join(phrase.split()) not in ' '.join(open(page).read().split()):
    sys.exit('the page ' + page + ' does not say: ' + phrase)
print(phrase, end='')
PY
}

# Run a command that the page names in its prose (in backticks, not in a
# command block), exactly as the page writes it.
prose_run() {
  text_from_page "$1" "\`$2\`" >/dev/null || exit 1
  printf '$ %s\n' "$2" >&2
  eval "$2"
}

# Write the block that follows "Save this as `<file>`" on a page to <file>.
save_yaml_from_page() {
  python3 - "$module_directory/$1" "$2" "$work_directory/$2" <<'PY'
import re, sys
page, name, target = sys.argv[1:]
text = open(page).read()
match = re.search(r'as `' + re.escape(name) + r'`.*?```yaml\n(.*?)```', text, re.S)
if not match:
    sys.exit('no yaml block for ' + name + ' in ' + page)
open(target, 'w').write(match.group(1))
PY
}

# Write the YAML block from a page and apply it with the command the page uses.
save_from_page() {
  save_yaml_from_page "$1" "$2"
  page_run "$1" "kubectl apply -f $2"
}

# Squeeze runs of spaces and tabs to one space, so that table rows compare
# with the rows that a page shows.
squeeze() {
  tr -s ' \t' '  '
}

checks=0
expect() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == *"$3"* ]] || { printf 'FAIL: %s\nwanted: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

expect_equal() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == "$3" ]] || { printf 'FAIL: %s\nwanted exactly: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

expect_no() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" != *"$3"* ]] || { printf 'FAIL: %s\nunwanted: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

# Expect the output to have a row that the page shows, ignoring column widths.
expect_row() {
  expect "$1" "$(printf '%s\n' "$2" | squeeze)" "$(text_from_page "$3" "$4")"
}

# Wait, at most about 5 minutes, until the API server answers /readyz. The
# control-plane static Pods restart during an upgrade and a kubelet restart.
wait_for_api() {
  local attempt
  for attempt in $(seq 1 60); do
    [[ "$(kubectl get --raw=/readyz 2>/dev/null || true)" == ok ]] && return 0
    sleep 5
  done
  printf 'the API server did not answer /readyz within 5 minutes\n' >&2
  sudo crictl ps -a >&2 || true
  exit 1
}

# Wait, at most about 5 minutes, until a jsonpath of an object has a value.
wait_for_value() {
  local wanted="$1" value='' attempt
  shift
  for attempt in $(seq 1 60); do
    value="$(kubectl "$@" 2>/dev/null || true)"
    [[ "$value" == "$wanted" ]] && return 0
    sleep 5
  done
  printf 'kubectl %s gave %s, not %s, within 5 minutes\n' "$*" "$value" "$wanted" >&2
  exit 1
}

# Wait, at most about 5 minutes, until every Pod in the cluster is Running
# and ready.
wait_for_running_pods() {
  local attempt not_running not_ready
  for attempt in $(seq 1 60); do
    not_running="$(kubectl get pods -A --field-selector=status.phase!=Running -o name 2>/dev/null || echo error)"
    not_ready="$(kubectl get pods -A -o jsonpath='{range .items[*]}{range .status.containerStatuses[*]}{.ready}{"\n"}{end}{end}' 2>/dev/null | grep -c false || true)"
    [[ -z "$not_running" && "$not_ready" == 0 ]] && return 0
    sleep 5
  done
  kubectl get pods -A -o wide >&2 || true
  printf 'not every Pod was Running and ready within 5 minutes\n' >&2
  exit 1
}

# Playground guide: the starting state
guide=playground/docs/overview.md
current_context="$(page_run "$guide" 'kubectl config current-context')"
expect_equal 'guide: the context is the playground cluster' "$current_context" "$(text_from_page "$guide" "kubernetes-admin@$cluster_name")"
guide_nodes="$(page_run "$guide" 'kubectl get nodes')"
printf '%s\n' "$guide_nodes"
expect_equal 'guide: the cluster has one node' "$(tail -n +2 <<<"$guide_nodes" | wc -l | tr -d ' ')" 1
expect 'guide: the only node is controlplane' "$(tail -1 <<<"$guide_nodes" | squeeze)" "$(text_from_page "$guide" 'The only node is `controlplane`' | sed 's/.*`\(.*\)`/\1/') Ready"
expect_equal 'guide: the node has no control-plane taint' "$(kubectl get node controlplane -o jsonpath='{.spec.taints}')" ''
expect_equal 'guide: probe has two ready replicas' "$(kubectl -n starfleet get deployment probe -o jsonpath='{.status.readyReplicas}')" 2
expect_equal 'guide: shuttle and drifter are bare Pods' "$(kubectl -n starfleet get pod shuttle -o jsonpath='{.metadata.ownerReferences}')$(kubectl -n outpost get pod drifter -o jsonpath='{.metadata.ownerReferences}')" ''
expect_equal 'guide: kubeadm, kubectl and kubelet are on hold' "$(apt-mark showhold)" "$(printf 'kubeadm\nkubectl\nkubelet')"
expect_equal 'guide: etcdctl and etcdutl are in /usr/local/bin' "$(command -v etcdctl) $(command -v etcdutl)" '/usr/local/bin/etcdctl /usr/local/bin/etcdutl'
expect 'guide: the package repository is the local copy' "$(cat /etc/apt/sources.list.d/kubernetes.list)" 'file:/opt/kubernetes-apt/v1.35/'

# Versions, skew and support
page=course-01-versions-skew-and-support.md
versions="$(page_run "$page" 'kubectl version')"
printf '%s\n' "$versions"
expect 'kubectl version shows the client version' "$versions" "$(text_from_page "$page" 'Client Version: v1.35.10')"
expect 'kubectl version shows the server version' "$versions" "$(text_from_page "$page" 'Server Version: v1.35.10')"
expect 'kubectl version shows the Kustomize version' "$versions" 'Kustomize Version: v5.'
nodes_wide="$(page_run "$page" 'kubectl get nodes -o wide')"
printf '%s\n' "$nodes_wide"
expect 'the node is Ready with kubelet v1.35.10' "$(squeeze <<<"$nodes_wide")" "$(text_from_page "$page" 'controlplane Ready control-plane')"
expect 'the VERSION column is v1.35.10' "$(squeeze <<<"$nodes_wide")" ' v1.35.10 '
expect 'the runtime column is containerd' "$nodes_wide" 'containerd://'
images="$(page_run "$page" 'kubectl -n kube-system get pods -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[*].image')"
printf '%s\n' "$images"
expect_row 'kube-apiserver image is v1.35.10' "$images" "$page" 'kube-apiserver-controlplane registry.k8s.io/kube-apiserver:v1.35.10'
expect_row 'kube-controller-manager image is v1.35.10' "$images" "$page" 'kube-controller-manager-controlplane registry.k8s.io/kube-controller-manager:v1.35.10'
expect_row 'kube-scheduler image is v1.35.10' "$images" "$page" 'kube-scheduler-controlplane registry.k8s.io/kube-scheduler:v1.35.10'
expect 'kube-proxy image is v1.35.10' "$images" "$(text_from_page "$page" 'registry.k8s.io/kube-proxy:v1.35.10')"
expect_row 'etcd image has its own version' "$images" "$page" 'etcd-controlplane registry.k8s.io/etcd:3.6.6-0'
expect 'coredns image has its own version' "$images" "$(text_from_page "$page" 'registry.k8s.io/coredns/coredns:v1.13.1')"
kubeadm_version="$(prose_run "$page" 'kubeadm version')"
printf '%s\n' "$kubeadm_version"
expect 'kubeadm version is v1.35.10' "$kubeadm_version" 'GitVersion:"v1.35.10"'
text_from_page "$page" 'here it is `v1.35.10`' >/dev/null

# Cordon, drain and disruption budgets
page=course-02-cordon-drain-and-disruption-budgets.md
save_from_page "$page" pdb-probe-budget.yaml
wait_for_value 1 -n starfleet get pdb probe-budget -o jsonpath='{.status.disruptionsAllowed}'
budget="$(page_run "$page" 'kubectl -n starfleet get pdb probe-budget')"
printf '%s\n' "$budget"
expect 'the budget allows one disruption' "$(squeeze <<<"$budget")" 'probe-budget N/A 1 1 '
bare_drain="$(page_fails "$page" 'kubectl drain controlplane --ignore-daemonsets --timeout=60s')"
printf '%s\n' "$bare_drain"
expect 'the drain cordoned the node first' "$bare_drain" "$(text_from_page "$page" 'node/controlplane cordoned')"
expect 'the drain stops on the bare Pods' "$bare_drain" "$(text_from_page "$page" 'cannot delete Pods that declare no controller (use --force to override): outpost/drifter, starfleet/shuttle')"
expect_no 'the drain evicted nothing' "$bare_drain" 'evicting pod'
expect 'the node stays cordoned' "$(kubectl get nodes)" "$(text_from_page "$page" 'Ready,SchedulingDisabled')"
budget_drain="$(page_fails "$page" 'kubectl drain controlplane --ignore-daemonsets --pod-selector app=probe --timeout=60s')"
printf '%s\n' "$budget_drain"
expect 'the node is already cordoned' "$budget_drain" "$(text_from_page "$page" 'node/controlplane already cordoned')"
expect 'the API server refused an eviction for the budget' "$budget_drain" "$(text_from_page "$page" "Cannot evict pod as it would violate the pod's disruption budget.")"
expect_equal 'the API server accepted exactly one eviction' "$(grep -c '^pod/probe-.* evicted$' <<<"$budget_drain" || true)" 1
expect 'the drain ended at its timeout' "$budget_drain" "$(text_from_page "$page" 'global timeout reached: 1m0s')"
probe_pods="$(page_run "$page" 'kubectl -n starfleet get pods -l app=probe -o wide')"
printf '%s\n' "$probe_pods"
expect_equal 'one probe replica is Pending' "$(grep -c ' Pending ' <<<"$probe_pods" || true)" 1
expect_equal 'one probe replica is Running and ready' "$(grep -cE ' 1/1 +Running ' <<<"$probe_pods" || true)" 1
wait_for_value 0 -n starfleet get pdb probe-budget -o jsonpath='{.status.disruptionsAllowed}'
budget="$(page_run "$page" 'kubectl -n starfleet get pdb probe-budget')"
printf '%s\n' "$budget"
expect 'the budget now allows no disruption' "$(squeeze <<<"$budget")" 'probe-budget N/A 1 0 '
uncordon="$(page_run "$page" 'kubectl uncordon controlplane')"
expect_equal 'kubectl uncordons the node' "$uncordon" "$(text_from_page "$page" 'node/controlplane uncordoned')"
wait_for_value 2 -n starfleet get deployment probe -o jsonpath='{.status.readyReplicas}'
wait_for_value 1 -n starfleet get pdb probe-budget -o jsonpath='{.status.disruptionsAllowed}'
expect 'the node is Ready again' "$(squeeze <<<"$(kubectl get nodes)")" 'controlplane Ready control-plane'
expect_equal 'both probe replicas are Running' "$(kubectl -n starfleet get pods -l app=probe --no-headers | grep -cE ' 1/1 +Running ' || true)" 2
expect_equal 'the budget allows one disruption again' "$(kubectl -n starfleet get pdb probe-budget -o jsonpath='{.status.disruptionsAllowed}')" 1
expect_equal 'the bare Pods were never touched' "$(kubectl -n starfleet get pod shuttle -o jsonpath='{.status.phase}') $(kubectl -n outpost get pod drifter -o jsonpath='{.status.phase}')" 'Running Running'
# The next page drains the node again and needs the budget gone.
prose_run "$page" 'kubectl -n starfleet delete pdb probe-budget'

# The kubeadm upgrade sequence
page=course-03-the-kubeadm-upgrade-sequence.md
old_list="$(page_run "$page" 'cat /etc/apt/sources.list.d/kubernetes.list')"
expect_equal 'the repository line names v1.35' "$old_list" "$(text_from_page "$page" 'deb [signed-by=/etc/apt/keyrings/astrona-kubernetes-local.gpg] file:/opt/kubernetes-apt/v1.35/deb/ /')"
page_run "$page" "sudo sed -i 's#/v1.35/#/v1.36/#' /etc/apt/sources.list.d/kubernetes.list"
new_list="$(page_run "$page" 'cat /etc/apt/sources.list.d/kubernetes.list')"
expect_equal 'the repository line names v1.36' "$new_list" "$(text_from_page "$page" 'deb [signed-by=/etc/apt/keyrings/astrona-kubernetes-local.gpg] file:/opt/kubernetes-apt/v1.36/deb/ /')"
apt_update="$(page_run "$page" 'sudo apt-get update' 2>&1)"
expect 'apt-get update reads the v1.36 repository' "$(squeeze <<<"$apt_update")" "$(text_from_page "$page" 'file:/opt/kubernetes-apt/v1.36/deb InRelease')"
madison="$(page_run "$page" 'apt-cache madison kubeadm')"
printf '%s\n' "$madison"
expect 'madison offers kubeadm 1.36.6-1.1' "$(squeeze <<<"$madison")" "$(text_from_page "$page" 'kubeadm | 1.36.6-1.1 | file:/opt/kubernetes-apt/v1.36/deb Packages')"
kubeadm_unhold="$(page_run "$page" 'sudo apt-mark unhold kubeadm')"
expect_equal 'apt-mark cancels the hold on kubeadm' "$kubeadm_unhold" "$(text_from_page "$page" 'Canceled hold on kubeadm.')"
page_run "$page" 'sudo apt-get install -y kubeadm=1.36.6-1.1'
kubeadm_hold="$(page_run "$page" 'sudo apt-mark hold kubeadm')"
expect_equal 'apt-mark holds kubeadm again' "$kubeadm_hold" "$(text_from_page "$page" 'kubeadm set on hold.')"
expect_equal 'kubeadm is v1.36.6' "$(page_run "$page" 'kubeadm version -o short')" "$(text_from_page "$page" 'v1.36.6')"
plan="$(page_run "$page" 'sudo kubeadm upgrade plan' 2>&1)"
printf '%s\n' "$plan"
plan_squeezed="$(squeeze <<<"$plan")"
expect 'plan shows the cluster version' "$plan_squeezed" "$(text_from_page "$page" '[upgrade/versions] Cluster version: 1.35.10')"
expect 'plan shows the kubeadm version' "$plan_squeezed" "$(text_from_page "$page" '[upgrade/versions] kubeadm version: v1.36.6')"
expect 'plan lists the kubelet as a manual upgrade' "$plan_squeezed" "$(text_from_page "$page" 'kubelet controlplane v1.35.10 v1.36.6')"
expect 'plan upgrades kube-apiserver' "$plan_squeezed" "$(text_from_page "$page" 'kube-apiserver controlplane v1.35.10 v1.36.6')"
expect 'plan upgrades kube-proxy' "$plan_squeezed" "$(text_from_page "$page" 'kube-proxy 1.35.10 v1.36.6')"
expect 'plan upgrades CoreDNS' "$plan_squeezed" "$(text_from_page "$page" 'CoreDNS v1.13.1 v1.14.2')"
expect 'plan upgrades etcd' "$plan_squeezed" "$(text_from_page "$page" 'etcd controlplane 3.6.6-0 3.6.8-0')"
expect 'plan gives the apply command' "$plan_squeezed" "$(text_from_page "$page" 'kubeadm upgrade apply v1.36.6')"
apply="$(page_run "$page" 'sudo kubeadm upgrade apply v1.36.6 --yes' 2>&1)"
printf '%s\n' "$apply" | tail -n 30
expect 'apply backs up the old etcd manifest' "$apply" 'backing up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-'
expect 'apply upgraded kube-apiserver' "$apply" "$(text_from_page "$page" '[upgrade/staticpods] Component "kube-apiserver" upgraded successfully!')"
expect 'apply applied CoreDNS' "$apply" "$(text_from_page "$page" '[addons] Applied essential addon: CoreDNS')"
expect 'apply applied kube-proxy' "$apply" "$(text_from_page "$page" '[addons] Applied essential addon: kube-proxy')"
expect 'apply reports success' "$apply" "$(text_from_page "$page" '[upgrade] SUCCESS! A control plane node of your cluster was upgraded to "v1.36.6".')"
wait_for_api
expect_equal 'shuttle is deleted' "$(page_run "$page" 'kubectl -n starfleet delete pod shuttle')" "$(text_from_page "$page" 'pod "shuttle" deleted from starfleet namespace')"
expect_equal 'drifter is deleted' "$(page_run "$page" 'kubectl -n outpost delete pod drifter')" "$(text_from_page "$page" 'pod "drifter" deleted from outpost namespace')"
drain="$(page_run "$page" 'kubectl drain controlplane --ignore-daemonsets --timeout=120s' 2>&1)"
printf '%s\n' "$drain"
expect 'the drain cordons the node' "$drain" "$(text_from_page "$page" 'node/controlplane cordoned')"
expect 'the drain skips the kube-proxy DaemonSet Pod' "$drain" 'Warning: ignoring DaemonSet-managed Pods: kube-system/kube-proxy-'
expect 'the drain evicts the coredns Pods' "$drain" 'pod/coredns-'
expect 'the drain evicts the probe Pods' "$drain" 'pod/probe-'
expect 'the node is drained' "$drain" "$(text_from_page "$page" 'node/controlplane drained')"
expect_equal 'apt-mark cancels the holds' "$(page_run "$page" 'sudo apt-mark unhold kubelet kubectl')" "$(printf '%s\n%s' "$(text_from_page "$page" 'Canceled hold on kubelet.')" "$(text_from_page "$page" 'Canceled hold on kubectl.')")"
page_run "$page" 'sudo apt-get install -y kubelet=1.36.6-1.1 kubectl=1.36.6-1.1'
expect_equal 'apt-mark holds the packages again' "$(page_run "$page" 'sudo apt-mark hold kubelet kubectl')" "$(printf '%s\n%s' "$(text_from_page "$page" 'kubelet set on hold.')" "$(text_from_page "$page" 'kubectl set on hold.')")"
page_run "$page" 'sudo systemctl daemon-reload'
page_run "$page" 'sudo systemctl restart kubelet'
# The page runs uncordon right after the restart. A script is faster than a
# person, so wait until the API server answers first.
wait_for_api
expect_equal 'kubectl uncordons the node' "$(page_run "$page" 'kubectl uncordon controlplane')" "$(text_from_page "$page" 'node/controlplane uncordoned')"
wait_for_value 'True v1.36.6' get node controlplane -o jsonpath='{.status.conditions[?(@.type=="Ready")].status} {.status.nodeInfo.kubeletVersion}'
upgraded_nodes="$(page_run "$page" 'kubectl get nodes')"
printf '%s\n' "$upgraded_nodes"
expect 'the node is Ready' "$(squeeze <<<"$upgraded_nodes")" 'controlplane Ready control-plane'
expect 'the node runs kubelet v1.36.6' "$upgraded_nodes" "$(text_from_page "$page" 'v1.36.6')"
expect_equal 'all three packages are on hold' "$(page_run "$page" 'apt-mark showhold')" "$(printf 'kubeadm\nkubectl\nkubelet')"
upgraded_versions="$(page_run "$page" 'kubectl version')"
printf '%s\n' "$upgraded_versions"
expect 'the client is v1.36.6' "$upgraded_versions" "$(text_from_page "$page" 'Client Version: v1.36.6')"
expect 'the server is v1.36.6' "$upgraded_versions" "$(text_from_page "$page" 'Server Version: v1.36.6')"
# The page says to check `kubectl get pods -A` until all Pods are Running.
wait_for_running_pods
text_from_page "$page" 'Check with `kubectl get pods -A` until all Pods are `Running`' >/dev/null
backups="$(prose_run "$page" 'sudo ls /etc/kubernetes/tmp')"
printf '%s\n' "$backups"
expect 'kubeadm kept a copy of the etcd data' "$backups" "$(text_from_page "$page" 'kubeadm-backup-etcd-')"
expect 'kubeadm kept the old static Pod manifests' "$backups" "$(text_from_page "$page" 'kubeadm-backup-manifests-')"
expect 'kubeadm kept the old kubelet configuration' "$backups" "$(text_from_page "$page" 'kubeadm-kubelet-config-')"
expect_equal 'there are three backup directories' "$(wc -l <<<"$backups" | tr -d ' ')" 3

# Snapshot and verify (on the upgraded cluster)
page=course-04-snapshot-and-verify.md
etcd_flags="$(page_run "$page" "kubectl -n kube-system get pod -l component=etcd -o jsonpath='{range .items[0].spec.containers[0].command[*]}{@}{\"\\n\"}{end}'")"
printf '%s\n' "$etcd_flags"
text_from_page "$page" 'The output has 20 lines' >/dev/null
expect_equal 'the etcd command has 20 lines' "$(grep -c . <<<"$etcd_flags")" 20
for flag in --cert-file=/etc/kubernetes/pki/etcd/server.crt --client-cert-auth=true --data-dir=/var/lib/etcd --key-file=/etc/kubernetes/pki/etcd/server.key --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt; do
  expect_equal "etcd runs with $flag" "$(grep -cxF -- "$(text_from_page "$page" "$flag")" <<<"$etcd_flags" || true)" 1
done
expect 'etcd listens on the local client address' "$(grep -- '--listen-client-urls=' <<<"$etcd_flags")" "$(text_from_page "$page" '--listen-client-urls=https://127.0.0.1:2379,')"
etcdctl_version="$(page_run "$page" 'etcdctl version')"
printf '%s\n' "$etcdctl_version"
expect_equal 'etcdctl is 3.6.6 with API 3.6' "$etcdctl_version" "$(printf '%s\n%s' "$(text_from_page "$page" 'etcdctl version: 3.6.6')" "$(text_from_page "$page" 'API version: 3.6')")"
# The page writes the command on six lines, joined with backslashes.
snapshot_command=$'sudo etcdctl \\\n  --endpoints=https://127.0.0.1:2379 \\\n  --cacert=/etc/kubernetes/pki/etcd/ca.crt \\\n  --cert=/etc/kubernetes/pki/etcd/server.crt \\\n  --key=/etc/kubernetes/pki/etcd/server.key \\\n  snapshot save /var/backups/etcd-snapshot.db'
snapshot="$(page_run "$page" "$snapshot_command" 2>&1)"
printf '%s\n' "$snapshot"
expect 'etcdctl saved the snapshot' "$snapshot" "$(text_from_page "$page" 'Snapshot saved at /var/backups/etcd-snapshot.db')"
expect 'etcdctl names the server version' "$snapshot" "$(text_from_page "$page" 'Server version 3.6.0')"
snapshot_file="$(page_run "$page" 'sudo ls -l /var/backups/etcd-snapshot.db')"
printf '%s\n' "$snapshot_file"
expect 'the snapshot is root only, mode 0600' "$snapshot_file" "$(text_from_page "$page" '-rw------- 1 root root')"
expect_equal 'the snapshot is not empty' "$(awk '{print ($5 > 0) ? "not empty" : "empty"}' <<<"$snapshot_file")" 'not empty'
snapshot_status="$(page_run "$page" 'sudo etcdutl snapshot status /var/backups/etcd-snapshot.db --write-out=table')"
printf '%s\n' "$snapshot_status"
expect 'etcdutl prints the table header' "$(squeeze <<<"$snapshot_status")" "$(text_from_page "$page" '| HASH | REVISION | TOTAL KEYS | TOTAL SIZE | VERSION |')"
# The columns are padded with spaces, as in the page row; squeeze them first.
expect 'the snapshot has storage version 3.6.0' "$(sed -n 4p <<<"$snapshot_status" | squeeze)" '| 3.6.0 |'
expect_equal 'the snapshot has a hash' "$(sed -n 4p <<<"$snapshot_status" | awk -F'|' '{gsub(/ /, "", $2); print ($2 != "" && $2 != "0") ? "hash" : "no hash"}')" hash
restore="$(page_run "$page" 'sudo etcdutl snapshot restore /var/backups/etcd-snapshot.db --data-dir /var/lib/etcd-restored' 2>&1)"
printf '%s\n' "$restore" | tail -n 1
expect 'etcdutl restored the snapshot' "$restore" "$(text_from_page "$page" 'restored snapshot')"
expect 'the restore names the new data directory' "$restore" "$(text_from_page "$page" '"data-dir": "/var/lib/etcd-restored"')"
expect_equal 'the restored directory holds a member directory' "$(sudo ls /var/lib/etcd-restored)" member
# The page says not to point etcd at the restored data on the playground.
prose_run "$page" 'sudo rm -rf /var/lib/etcd-restored'
expect_equal 'the restored copy is removed' "$(sudo test -e /var/lib/etcd-restored && echo present || echo gone)" gone
verify_nodes="$(page_run "$page" 'kubectl get nodes')"
printf '%s\n' "$verify_nodes"
expect 'the node is Ready at the target version' "$(squeeze <<<"$verify_nodes")" 'controlplane Ready control-plane'
expect 'the node shows v1.36.6' "$verify_nodes" "$(text_from_page "$page" 'v1.36.6')"
readyz="$(page_run "$page" "kubectl get --raw='/readyz?verbose'")"
printf '%s\n' "$readyz"
text_from_page "$page" 'The `readyz` output has 37 check lines' >/dev/null
expect_equal 'readyz has 37 check lines' "$(grep -c '^\[' <<<"$readyz")" 37
expect_no 'no readyz check failed' "$readyz" '[-]'
expect 'readyz checks etcd' "$readyz" "$(text_from_page "$page" '[+]etcd ok')"
expect_equal 'readyz passed' "$(tail -1 <<<"$readyz")" "$(text_from_page "$page" 'readyz check passed')"
# Keep the command output only: page_run prints the command line first.
not_running="$(page_run "$page" 'kubectl get pods -A --field-selector=status.phase!=Running' 2>&1 | grep -v '^\$ ')"
expect_equal 'no Pod is outside the Running phase' "$not_running" "$(text_from_page "$page" 'No resources found')"
certificates="$(page_run "$page" 'sudo kubeadm certs check-expiration')"
printf '%s\n' "$certificates"
text_from_page "$page" 'The certificates run for one more year' >/dev/null
expect_equal 'admin.conf runs for one more year' "$(grep -cE '^admin.conf .* 36[45]d ' <<<"$certificates" || true)" 1
expect_equal 'apiserver runs for one more year' "$(grep -cE '^apiserver .* 36[45]d ' <<<"$certificates" || true)" 1
expect 'the CA is not renewed and has years left' "$(grep -E '^ca ' <<<"$certificates")" "$(text_from_page "$page" '9y')"
expect 'admin.conf is not externally managed' "$(grep '^admin.conf ' <<<"$certificates" | squeeze)" ' ca no'
kubectl -n starfleet rollout status deployment/probe --timeout=180s
# kube-proxy programs the new Service a moment after the rollout, so the first
# request can get "Connection refused". Wait, at most about a minute, for an answer.
probe_ip="$(kubectl -n starfleet get service probe -o jsonpath='{.spec.clusterIP}')"
for attempt in $(seq 1 30); do
  curl -s -m 3 "http://$probe_ip/" >/dev/null && break
  sleep 2
done
reply="$(page_run "$page" "curl -s \"http://\$(kubectl -n starfleet get service probe -o jsonpath='{.spec.clusterIP}')/\"")"
printf '%s\n' "$reply"
expect 'a probe Pod answered with version v1' "$reply" "$(text_from_page "$page" 'version=v1 host=probe-')"
expect 'the answer has the greeting' "$reply" "$(text_from_page "$page" 'greeting=hello')"

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
