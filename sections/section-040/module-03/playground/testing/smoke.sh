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
# The pages build on each other: the first page patches and drains the node
# and restarts containerd, the second checks the cluster and leaves the
# PodDisruptionBudget `probe`, and the third takes an etcd snapshot and runs a
# restore drill. At the end the script also runs the real restore that the
# third page describes in prose, because nothing comes after it.
set -euo pipefail
# Keep set -e inside $(...), so a failed page lookup also stops a captured command.
shopt -s inherit_errexit 2>/dev/null || true
cluster_name=astro-ats-032-playground-040-03
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
etcd_manifest=/etc/kubernetes/manifests/etcd.yaml

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

# Print the text block that follows the first command block containing the
# given command on a page: the output the page shows for that command.
output_from_page() {
  python3 - "$module_directory/$1" "$2" <<'PY'
import re, sys
page, command = sys.argv[1:]
match = re.search(r'```sh\n[^`]*' + re.escape(command) + r'[^`]*```\s*```text\n(.*?)```', open(page).read(), re.S)
if not match:
    sys.exit('no output block after ' + command + ' in ' + page)
print(match.group(1), end='')
PY
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

# Write the block that follows "Replace the content of `<file>`" on a page to <file>.
save_replacement_from_page() {
  python3 - "$module_directory/$1" "$2" "$work_directory/$2" <<'PY'
import re, sys
page, name, target = sys.argv[1:]
text = open(page).read()
match = re.search(r'Replace the content of `' + re.escape(name) + r'`.*?```yaml\n(.*?)```', text, re.S)
if not match:
    sys.exit('no replacement yaml block for ' + name + ' in ' + page)
open(target, 'w').write(match.group(1))
PY
}

# Squeeze runs of spaces and tabs to one space, so that table rows compare
# with the rows that a page shows.
squeeze() {
  tr -s ' \t' '  '
}

# Run a command line (with pipes) given as one string.
run_command_line() {
  eval "$1"
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

# Run a command until its output contains the text, at most about 2 minutes,
# and print the last output.
wait_for_output() {
  local wanted="$1" output='' attempt
  shift
  for attempt in $(seq 1 40); do
    output="$("$@" 2>&1 || true)"
    [[ "$output" == *"$wanted"* ]] && break
    sleep 3
  done
  printf '%s\n' "$output"
}

# Run a command until its output no longer contains the text, at most about
# 2 minutes, and print the last output.
wait_for_output_without() {
  local unwanted="$1" output='' attempt
  shift
  for attempt in $(seq 1 40); do
    output="$("$@" 2>&1 || true)"
    [[ "$output" != *"$unwanted"* ]] && break
    sleep 3
  done
  printf '%s\n' "$output"
}

# Wait, at most about 5 minutes, until a kubectl command prints a value.
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

# Wait, at most about 2 minutes, until the Deployment probe has exactly the
# given number of Pods (Pods of a scale-down are gone).
wait_for_probe_pods() {
  local wanted="$1" count='' attempt
  for attempt in $(seq 1 40); do
    count="$(kubectl -n starfleet get pods -l app=probe --no-headers 2>/dev/null | grep -c . || true)"
    [[ "$count" == "$wanted" ]] && return 0
    sleep 3
  done
  printf 'the Deployment probe has %s Pods, not %s\n' "$count" "$wanted" >&2
  exit 1
}

# The ID of the running etcd container.
etcd_container() {
  sudo crictl ps --name '^etcd$' --state Running -q 2>/dev/null | head -n 1
}

# Wait, at most about 5 minutes, until the kubelet runs a new etcd container
# (not the one given), etcd answers and the API server answers /readyz.
wait_for_new_etcd_and_api() {
  local old_container="$1" new_container attempt
  for attempt in $(seq 1 60); do
    new_container="$(etcd_container || true)"
    if [[ -n "$new_container" && "$new_container" != "$old_container" ]] &&
      sudo etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key --command-timeout=5s endpoint health >/dev/null 2>&1 &&
      [[ "$(kubectl get --raw=/readyz 2>/dev/null || true)" == ok ]]; then
      return 0
    fi
    sleep 5
  done
  printf 'etcd or the API server did not come back with the restored data within 5 minutes\n' >&2
  sudo crictl ps -a >&2 || true
  exit 1
}

# Print the REVISION and TOTAL KEYS columns of an etcdutl status table.
revision_and_keys() {
  sed -n 4p | awk -F'|' '{gsub(/ /, "", $3); gsub(/ /, "", $4); print $3, $4}'
}

# Print the HASH column of an etcdutl status table.
snapshot_hash() {
  sed -n 4p | awk -F'|' '{gsub(/ /, "", $2); print $2}'
}

# Playground guide: the starting state
guide=playground/docs/overview.md
guide_nodes="$(page_run "$guide" 'kubectl get nodes')"
printf '%s\n' "$guide_nodes"
expect_equal 'guide: the cluster has one node' "$(tail -n +2 <<<"$guide_nodes" | grep -c .)" 1
expect 'guide: the node is controlplane' "$(tail -1 <<<"$guide_nodes" | squeeze)" "$(text_from_page "$guide" 'The output lists one node, `controlplane`' | sed 's/.*`\(.*\)`/\1/') Ready"
expect_equal 'guide: kubectl has the cluster-admin role' "$(kubectl auth can-i '*' '*' --all-namespaces)" yes
expect_equal 'guide: probe has two ready replicas' "$(kubectl -n starfleet get deployment probe -o jsonpath='{.status.readyReplicas}')" 2
expect_equal 'guide: shuttle and drifter are bare Pods' "$(kubectl -n starfleet get pod shuttle -o jsonpath='{.metadata.ownerReferences}')$(kubectl -n outpost get pod drifter -o jsonpath='{.metadata.ownerReferences}')" ''
expect_equal 'guide: etcdctl and etcdutl are in /usr/local/bin' "$(command -v etcdctl) $(command -v etcdutl)" '/usr/local/bin/etcdctl /usr/local/bin/etcdutl'

# Patch the operating system and container runtime on nodes
page=course-01-patch-the-operating-system-and-container-runtime-on-nodes.md
node_info="$(page_run "$page" 'kubectl get nodes -o custom-columns=NAME:.metadata.name,OS:.status.nodeInfo.osImage,KERNEL:.status.nodeInfo.kernelVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion')"
printf '%s\n' "$node_info"
kernel="$(page_run "$page" 'uname -r')"
runtime="$(page_run "$page" 'containerd --version')"
printf '%s\n%s\n' "$kernel" "$runtime"
expect 'the node runs Ubuntu 24.04' "$node_info" 'Ubuntu 24.04'
expect 'the kubelet reports the kernel the host shows' "$(tail -1 <<<"$node_info" | squeeze)" " $kernel containerd://"
expect_equal 'the kubelet reports the runtime the host shows' "$(tail -1 <<<"$node_info" | awk '{print $NF}')" "containerd://$(awk '{print $3}' <<<"$runtime" | sed 's/^v//')"
expect 'containerd --version names containerd v2' "$runtime" "$(text_from_page "$page" 'containerd github.com/containerd/containerd/v2')"
# Without network apt-get update only prints warnings, as the page says.
page_run "$page" 'sudo apt-get update' || true
holds="$(page_run "$page" 'apt-mark showhold')"
expect_equal 'the three Kubernetes packages are held' "$holds" "$(printf 'kubeadm\nkubectl\nkubelet')"
simulation="$(page_run "$page" 'sudo apt-get upgrade --simulate')"
printf '%s\n' "$simulation"
expect 'the simulation calculates an upgrade' "$simulation" "$(text_from_page "$page" 'Calculating upgrade...')"
expect_no 'the simulation leaves kubeadm alone' "$simulation" 'Inst kubeadm'
expect_no 'the simulation leaves kubelet alone' "$simulation" 'Inst kubelet'
expect_no 'the simulation leaves kubectl alone' "$simulation" 'Inst kubectl'
# The command prints nothing and exits 1 when the marker file does not exist.
on_page "$page" 'test -f /var/run/reboot-required && echo reboot needed'
reboot_marker="$(page_run "$page" 'test -f /var/run/reboot-required && echo reboot needed' || true)"
expect_equal 'no reboot is needed' "$reboot_marker" ''
maintenance="$(page_run "$page" 'kubectl cordon controlplane')"
maintenance+=$'\n'"$(page_run "$page" 'kubectl taint nodes controlplane maintenance=patching:NoSchedule')"
expect 'the node is cordoned' "$maintenance" "$(text_from_page "$page" 'node/controlplane cordoned')"
expect 'the node is tainted' "$maintenance" "$(text_from_page "$page" 'node/controlplane tainted')"
expect 'the node is Ready,SchedulingDisabled' "$(page_run "$page" 'kubectl get nodes' | squeeze)" "$(text_from_page "$page" 'controlplane Ready,SchedulingDisabled control-plane')"
taints_command='kubectl describe node controlplane | grep -i -A2 taints'
taints="$(wait_for_output 'node.kubernetes.io/unschedulable:NoSchedule' page_run "$page" "$taints_command")"
printf '%s\n' "$taints"
expect 'the description lists the custom taint' "$(squeeze <<<"$taints")" "$(text_from_page "$page" 'Taints: maintenance=patching:NoSchedule')"
expect 'the description lists the taint of the cordon' "$taints" "$(text_from_page "$page" 'node.kubernetes.io/unschedulable:NoSchedule')"
expect 'the node is unschedulable' "$(squeeze <<<"$taints")" "$(text_from_page "$page" 'Unschedulable: true')"
expect_equal 'uncordon answers' "$(page_run "$page" 'kubectl uncordon controlplane')" "$(text_from_page "$page" 'node/controlplane uncordoned')"
taints="$(wait_for_output_without 'node.kubernetes.io/unschedulable' page_run "$page" "$taints_command")"
printf '%s\n' "$taints"
expect 'the custom taint stays after uncordon' "$(squeeze <<<"$taints")" 'Taints: maintenance=patching:NoSchedule'
expect_no 'the node controller removed its own taint' "$taints" 'node.kubernetes.io/unschedulable'
expect 'the node is schedulable again' "$(squeeze <<<"$taints")" "$(text_from_page "$page" 'Unschedulable: false')"
expect_equal 'the taint is removed' "$(page_run "$page" 'kubectl taint nodes controlplane maintenance=patching:NoSchedule-')" "$(text_from_page "$page" 'node/controlplane untainted')"
taints="$(page_run "$page" "$taints_command")"
printf '%s\n' "$taints"
expect 'the node has no taints' "$(squeeze <<<"$taints")" "$(text_from_page "$page" 'Taints: <none>')"
expect 'the node is still schedulable' "$(squeeze <<<"$taints")" 'Unschedulable: false'
bare_drain="$(page_fails "$page" 'kubectl drain controlplane --ignore-daemonsets')"
printf '%s\n' "$bare_drain"
expect 'the drain cordons the node' "$bare_drain" 'node/controlplane cordoned'
expect 'the drain stops on the bare Pods' "$bare_drain" "$(text_from_page "$page" 'cannot delete Pods that declare no controller (use --force to override): outpost/drifter, starfleet/shuttle')"
expect 'kubectl lists the node as still to drain' "$bare_drain" "$(text_from_page "$page" 'There are pending nodes to be drained:')"
expect_no 'the drain evicted nothing' "$bare_drain" 'evicting pod'
expect 'the node stays cordoned' "$(page_run "$page" 'kubectl get nodes' | squeeze)" 'controlplane Ready,SchedulingDisabled control-plane'
probe_drain="$(page_run "$page" 'kubectl drain controlplane --ignore-daemonsets --pod-selector=app=probe --timeout=120s' 2>&1)"
printf '%s\n' "$probe_drain"
expect 'the node is already cordoned' "$probe_drain" "$(text_from_page "$page" 'node/controlplane already cordoned')"
expect_equal 'both probe Pods are evicted' "$(grep -c '^pod/probe-.* evicted$' <<<"$probe_drain" || true)" 2
expect 'the node is drained' "$probe_drain" "$(text_from_page "$page" 'node/controlplane drained')"
workloads="$(page_run "$page" 'kubectl get pods -A -o wide --field-selector=metadata.namespace!=kube-system')"
printf '%s\n' "$workloads"
expect_equal 'the two new probe Pods are Pending' "$(grep -cE '^starfleet +probe-.* Pending ' <<<"$workloads" || true)" 2
expect 'drifter keeps running' "$(squeeze <<<"$workloads")" 'outpost drifter 1/1 Running'
expect 'shuttle keeps running' "$(squeeze <<<"$workloads")" 'starfleet shuttle 1/1 Running'
containerd_before="$(page_run "$page" 'systemctl show containerd --property=MainPID --property=ActiveEnterTimestamp')"
printf '%s\n' "$containerd_before"
page_run "$page" 'sudo systemctl restart containerd'
expect_equal 'containerd is active' "$(page_run "$page" 'systemctl is-active containerd')" "$(text_from_page "$page" 'active')"
containerd_after="$(page_run "$page" 'systemctl show containerd --property=MainPID --property=ActiveEnterTimestamp')"
printf '%s\n' "$containerd_after"
expect_equal 'containerd has a new process ID' "$([[ "$(grep MainPID= <<<"$containerd_after")" != "$(grep MainPID= <<<"$containerd_before")" ]] && echo new || echo same)" new
expect 'containerd has a start time' "$containerd_after" 'ActiveEnterTimestamp='
shuttle="$(page_run "$page" 'kubectl -n starfleet get pod shuttle')"
printf '%s\n' "$shuttle"
expect 'shuttle kept running with zero restarts' "$(squeeze <<<"$shuttle")" "$(text_from_page "$page" 'shuttle 1/1 Running 0')"
expect_equal 'the node becomes Ready' "$(page_run "$page" 'kubectl wait --for=condition=Ready node/controlplane --timeout=180s')" "$(text_from_page "$page" 'node/controlplane condition met')"
expect_equal 'the node is uncordoned' "$(page_run "$page" 'kubectl uncordon controlplane')" 'node/controlplane uncordoned'
rollout="$(page_run "$page" 'kubectl -n starfleet rollout status deployment/probe --timeout=180s')"
expect 'probe rolled out' "$rollout" "$(text_from_page "$page" 'deployment "probe" successfully rolled out')"
starfleet_pods="$(page_run "$page" 'kubectl -n starfleet get pods -o wide')"
printf '%s\n' "$starfleet_pods"
expect_equal 'both probe Pods run on the node' "$(grep -cE '^probe-.* 1/1 +Running .* controlplane ' <<<"$starfleet_pods" || true)" 2
expect 'shuttle still runs' "$(squeeze <<<"$starfleet_pods")" 'shuttle 1/1 Running 0'

# Verify the cluster after an upgrade
page=course-02-verify-the-cluster-after-an-upgrade.md
nodes_wide="$(page_run "$page" 'kubectl get nodes -o wide')"
printf '%s\n' "$nodes_wide"
expect 'the node is Ready' "$(squeeze <<<"$nodes_wide")" "$(text_from_page "$page" 'controlplane Ready control-plane')"
expect_no 'the node has no SchedulingDisabled mark' "$nodes_wide" SchedulingDisabled
expect 'the node shows v1.35.10' "$(squeeze <<<"$nodes_wide")" "$(text_from_page "$page" ' v1.35.10 ')"
livez="$(page_run "$page" "kubectl get --raw='/livez?verbose'")"
printf '%s\n' "$livez"
expect_equal 'livez starts with the ping check' "$(head -1 <<<"$livez")" "$(text_from_page "$page" '[+]ping ok')"
expect 'livez checks etcd' "$livez" "$(text_from_page "$page" '[+]etcd ok')"
expect_no 'no livez check failed' "$livez" '[-]'
expect_equal 'livez passed' "$(tail -1 <<<"$livez")" "$(text_from_page "$page" 'livez check passed')"
readyz="$(page_run "$page" "kubectl get --raw='/readyz?verbose'")"
printf '%s\n' "$readyz"
for readyz_check in etcd-readiness informer-sync shutdown; do
  text_from_page "$page" "\`$readyz_check\`" >/dev/null
  expect "readyz has the $readyz_check check" "$readyz" "[+]$readyz_check ok"
done
expect_no 'no readyz check failed' "$readyz" '[-]'
expect_equal 'readyz passed' "$(tail -1 <<<"$readyz")" "$(text_from_page "$page" 'readyz check passed')"
not_running="$(page_run "$page" 'kubectl get pods -A --field-selector=status.phase!=Running' 2>&1)"
expect_equal 'no Pod is outside the Running phase' "$not_running" "$(text_from_page "$page" 'No resources found')"
probe_pods="$(page_run "$page" 'kubectl -n starfleet get pods -l app=probe')"
printf '%s\n' "$probe_pods"
expect_equal 'two probe Pods are Running' "$(grep -cE '^probe-.* 1/1 +Running ' <<<"$probe_pods" || true)" 2
expect_equal 'the node is tainted' "$(page_run "$page" 'kubectl taint nodes controlplane maintenance=patching:NoSchedule')" "$(text_from_page "$page" 'node/controlplane tainted')"
expect_equal 'probe is scaled' "$(page_run "$page" 'kubectl -n starfleet scale deployment probe --replicas=3')" "$(text_from_page "$page" 'deployment.apps/probe scaled')"
probe_pods="$(wait_for_output ' Pending ' page_run "$page" 'kubectl -n starfleet get pods -l app=probe')"
printf '%s\n' "$probe_pods"
expect_equal 'the new Pod is Pending' "$(grep -cE '^probe-.* 0/1 +Pending ' <<<"$probe_pods" || true)" 1
expect_equal 'the two old Pods keep running' "$(grep -cE '^probe-.* 1/1 +Running ' <<<"$probe_pods" || true)" 2
# The page says to use the Pod name from your own output in place of its own.
describe_command="kubectl -n starfleet describe pod probe-7db6ffd7d6-8qnt6 | sed -n '/^Events:/,\$p'"
on_page "$page" "$describe_command"
pending_pod="$(kubectl -n starfleet get pods -l app=probe --field-selector=status.phase=Pending -o jsonpath='{.items[0].metadata.name}')"
events="$(wait_for_output FailedScheduling run_command_line "${describe_command/probe-7db6ffd7d6-8qnt6/$pending_pod}")"
printf '%s\n' "$events"
expect 'the events start with the Events heading' "$(head -1 <<<"$events")" 'Events:'
expect 'the scheduler reports FailedScheduling' "$(squeeze <<<"$events")" "$(text_from_page "$page" 'Warning FailedScheduling')"
expect 'the scheduler names the untolerated taint' "$events" "$(text_from_page "$page" '0/1 nodes are available: 1 node(s) had untolerated taint(s).')"
expect_equal 'the taint is removed' "$(page_run "$page" 'kubectl taint nodes controlplane maintenance=patching:NoSchedule-')" "$(text_from_page "$page" 'node/controlplane untainted')"
rollout="$(page_run "$page" 'kubectl -n starfleet rollout status deployment/probe --timeout=120s')"
printf '%s\n' "$rollout"
expect 'the third Pod started' "$rollout" "$(text_from_page "$page" 'deployment "probe" successfully rolled out')"
expect_equal 'probe is scaled back' "$(page_run "$page" 'kubectl -n starfleet scale deployment probe --replicas=2')" 'deployment.apps/probe scaled'
wait_for_probe_pods 2
save_yaml_from_page "$page" poddisruptionbudget-probe.yaml
expect_equal 'the budget is created' "$(page_run "$page" 'kubectl apply -f poddisruptionbudget-probe.yaml')" "$(text_from_page "$page" 'poddisruptionbudget.policy/probe created')"
wait_for_value '2 0' -n starfleet get pdb probe -o jsonpath='{.status.currentHealthy} {.status.disruptionsAllowed}'
budgets="$(page_run "$page" 'kubectl get pdb -A')"
printf '%s\n' "$budgets"
expect 'the budget allows no disruption' "$(squeeze <<<"$budgets")" "$(text_from_page "$page" 'starfleet probe 2 N/A 0')"
save_replacement_from_page "$page" poddisruptionbudget-probe.yaml
expect_equal 'the budget is configured' "$(page_run "$page" 'kubectl apply -f poddisruptionbudget-probe.yaml')" "$(text_from_page "$page" 'poddisruptionbudget.policy/probe configured')"
# The page reads the budget right after the apply. Wait until the disruption
# controller has written the new status.
wait_for_value 1 -n starfleet get pdb probe -o jsonpath='{.status.disruptionsAllowed}'
budgets="$(page_run "$page" 'kubectl get pdb -A')"
printf '%s\n' "$budgets"
expect 'the budget allows one disruption' "$(squeeze <<<"$budgets")" "$(text_from_page "$page" 'starfleet probe N/A 1 1')"
deprecated="$(page_run "$page" 'kubectl get --raw /metrics | grep apiserver_requested_deprecated_apis')"
printf '%s\n' "$deprecated"
expect 'the API server has the deprecated API metric' "$deprecated" "$(text_from_page "$page" '# TYPE apiserver_requested_deprecated_apis gauge')"
reply="$(page_run "$page" 'kubectl -n starfleet exec shuttle -- wget -q -T 3 -O- http://probe/')"
printf '%s\n' "$reply"
expect 'a probe Pod answered through the Service' "$reply" "$(text_from_page "$page" 'version=v1 host=probe-')"
expect 'the answer has the greeting' "$reply" "$(text_from_page "$page" 'greeting=hello')"
warnings="$(page_run "$page" 'kubectl get events -A --field-selector type=Warning')"
printf '%s\n' "$warnings"
expect 'the warning events include the FailedScheduling event' "$(squeeze <<<"$warnings")" "$(text_from_page "$page" 'Warning FailedScheduling pod/probe-')"

# Rollback limits and restore drills
page=course-03-rollback-limits-and-restore-drills.md
expect 'etcd runs as a static Pod' "$(page_run "$page" 'kubectl -n kube-system get pods -l component=etcd' | squeeze)" "$(text_from_page "$page" 'etcd-controlplane 1/1 Running')"
etcd_options='--endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key'
health="$(page_run "$page" "sudo etcdctl $etcd_options endpoint health" 2>&1)"
printf '%s\n' "$health"
expect 'etcd is healthy' "$health" "$(text_from_page "$page" 'https://127.0.0.1:2379 is healthy: successfully committed proposal')"
status="$(page_run "$page" "sudo etcdctl $etcd_options endpoint status --write-out=table")"
printf '%s\n' "$status"
expect 'the status table names the endpoint' "$(squeeze <<<"$status")" '| https://127.0.0.1:2379 |'
expect 'etcd is version 3.6.6 with storage version 3.6.0' "$(squeeze <<<"$status")" "$(text_from_page "$page" '| 3.6.6 | 3.6.0 |')"
expect 'the only member is the leader' "$(squeeze <<<"$status")" '| true | false |'
page_run "$page" 'sudo mkdir -p /var/backups/etcd'
snapshot="$(page_run "$page" "sudo etcdctl $etcd_options snapshot save /var/backups/etcd/before-upgrade.db" 2>&1)"
printf '%s\n' "$snapshot"
expect 'etcdctl saved the snapshot' "$snapshot" "$(text_from_page "$page" 'Snapshot saved at /var/backups/etcd/before-upgrade.db')"
expect 'etcdctl names the server version' "$snapshot" "$(text_from_page "$page" 'Server version 3.6.0')"
snapshot_status="$(page_run "$page" 'sudo etcdutl snapshot status /var/backups/etcd/before-upgrade.db --write-out=table')"
printf '%s\n' "$snapshot_status"
expect 'etcdutl prints the table header' "$(squeeze <<<"$snapshot_status")" "$(text_from_page "$page" '| HASH | REVISION | TOTAL KEYS | TOTAL SIZE | VERSION |')"
snapshot_numbers="$(revision_and_keys <<<"$snapshot_status")"
expect_equal 'the snapshot has a revision and keys' "$(awk '($1 > 0 && $2 > 0) {print "numbers"}' <<<"$snapshot_numbers")" numbers
backups="$(page_run "$page" 'sudo ls -l /var/backups/etcd')"
printf '%s\n' "$backups"
expect 'the snapshot is root only, mode 0600' "$(grep before-upgrade.db <<<"$backups")" "$(text_from_page "$page" '-rw------- 1 root root')"
drill="$(page_run "$page" 'sudo etcdutl snapshot restore /var/backups/etcd/before-upgrade.db --data-dir /var/lib/etcd-drill' 2>&1)"
printf '%s\n' "$drill" | tail -n 1
expect 'etcdutl restored the snapshot' "$drill" "$(text_from_page "$page" 'restored snapshot')"
expect 'the restore names the drill directory' "$drill" "$(text_from_page "$page" '"data-dir": "/var/lib/etcd-drill"')"
member="$(page_run "$page" 'sudo ls -l /var/lib/etcd-drill/member')"
printf '%s\n' "$member"
expect 'the drill has a snap folder' "$(squeeze <<<"$member")" 'drwx------ 2 root root'
expect_equal 'the drill has the snap and wal folders' "$(awk 'NR > 1 {print $NF}' <<<"$member" | tr '\n' ' ')" 'snap wal '
drill_status="$(page_run "$page" 'sudo etcdutl snapshot status /var/lib/etcd-drill/member/snap/db --write-out=table')"
printf '%s\n' "$drill_status"
expect_equal 'the drill database has the revision and keys of the snapshot' "$(revision_and_keys <<<"$drill_status")" "$snapshot_numbers"
expect_no 'the drill database has a different hash' "$(snapshot_hash <<<"$drill_status")" "$(snapshot_hash <<<"$snapshot_status")"
second_restore="$(page_fails "$page" 'sudo etcdutl snapshot restore /var/backups/etcd/before-upgrade.db --data-dir /var/lib/etcd-drill')"
printf '%s\n' "$second_restore"
expect 'etcdutl refuses a directory with data' "$second_restore" "$(text_from_page "$page" 'Error: data-dir "/var/lib/etcd-drill" not empty or could not be read')"
manifest_command='sudo grep -n "data-dir\|/var/lib/etcd\|etcd-data" /etc/kubernetes/manifests/etcd.yaml'
manifest_lines="$(page_run "$page" "$manifest_command")"
printf '%s\n' "$manifest_lines"
expect_equal 'the manifest names the data directory in the lines the page shows' "$manifest_lines" "$(output_from_page "$page" "$manifest_command")"

# The page describes a real restore in prose: restore with the two extra
# flags into a new directory, then change only line 91 (the hostPath of the
# volume etcd-data) to that directory. Nothing comes after this page, so run
# it here and check that the kubelet starts etcd on the restored data.
text_from_page "$page" '`--bump-revision 1000000000 --mark-compacted`' >/dev/null
text_from_page "$page" 'change only line 91 to the restored directory, for example `/var/lib/etcd-restore`' >/dev/null
sudo etcdutl snapshot restore /var/backups/etcd/before-upgrade.db --data-dir /var/lib/etcd-restore --bump-revision 1000000000 --mark-compacted
old_etcd="$(etcd_container)"
sudo sed -i '91s#path: /var/lib/etcd$#path: /var/lib/etcd-restore#' "$etcd_manifest"
restored_lines="$(page_run "$page" "$manifest_command")"
printf '%s\n' "$restored_lines"
expect 'line 91 names the restored directory' "$restored_lines" '91:      path: /var/lib/etcd-restore'
expect 'the container still reads /var/lib/etcd' "$restored_lines" '18:    - --data-dir=/var/lib/etcd'
expect 'the mount path stays /var/lib/etcd' "$restored_lines" '75:    - mountPath: /var/lib/etcd'
wait_for_new_etcd_and_api "$old_etcd"
expect 'etcd is healthy on the restored data' "$(page_run "$page" "sudo etcdctl $etcd_options endpoint health" 2>&1)" 'is healthy'
# After a restore, the page says to check the nodes, the API health, the
# budgets and a real request, with the commands of the verification page.
page=course-02-verify-the-cluster-after-an-upgrade.md
wait_for_value True get node controlplane -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
expect 'the node is Ready after the restore' "$(page_run "$page" 'kubectl get nodes -o wide' | squeeze)" 'controlplane Ready control-plane'
expect_equal 'readyz passes after the restore' "$(page_run "$page" "kubectl get --raw='/readyz?verbose'" | tail -1)" 'readyz check passed'
expect 'the budget of the snapshot time is back' "$(page_run "$page" 'kubectl get pdb -A' | squeeze)" 'starfleet probe N/A 1 '
kubectl -n starfleet rollout status deployment/probe --timeout=180s
expect 'a probe Pod answers after the restore' "$(page_run "$page" 'kubectl -n starfleet exec shuttle -- wget -q -T 3 -O- http://probe/')" 'version=v1 host=probe-'

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
