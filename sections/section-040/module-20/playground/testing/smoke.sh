#!/usr/bin/env bash
# Runs the commands that the module pages and the playground guide teach and
# fails when one of them does not give the result the page describes.
# Every command is first looked up on its page and then run exactly as the
# page writes it, and every YAML file comes from the page, so the pages and
# this test cannot drift apart. scripts/ci/test-playground.sh runs it with
# KUBECONFIG set to the playground cluster.
set -euo pipefail
# Keep set -e inside $(...), so a failed page lookup also stops a captured command.
shopt -s inherit_errexit 2>/dev/null || true
cluster_name=astro-ats-032-playground-040-02
context="${ASTRONA_KUBE_CONTEXT:-kind-$cluster_name}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
# The pages save files in the current folder, so work in an empty one.
cd "$work_directory"
node_name="$cluster_name-control-plane"
worker_name="$cluster_name-worker"

# The pages of this module run no node command. If one is added, it is written
# as `podman exec "$worker_name" ...`. The kind nodes run on the engine named in
# ASTRONA_CONTAINER_ENGINE (Docker in CI), so send an exec on a node of this
# cluster there. Every other podman command runs the real podman.
podman() {
  if [[ "${1:-}" == exec && "${2:-}" == "$cluster_name"-* ]]; then
    command "$engine" "$@"
  else
    command podman "$@"
  fi
}

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

# Write the block that follows "Save this as `<file>`" (or "as `<file>`") on a
# page to <file> in the work folder. The third argument is the block language.
save_block_from_page() {
  python3 - "$module_directory/$1" "$2" "${3:-yaml}" "$work_directory/$2" <<'PY'
import re, sys
page, name, language, target = sys.argv[1:]
text = open(page).read()
match = re.search(r'as `' + re.escape(name) + r'`.*?```' + re.escape(language) + r'\n(.*?)```', text, re.S)
if not match:
    sys.exit('no ' + language + ' block for ' + name + ' in ' + page)
open(target, 'w').write(match.group(1))
PY
}

save_yaml_from_page() {
  save_block_from_page "$1" "$2" yaml
}

# Write the YAML block from a page and apply it with the command the page uses.
save_from_page() {
  save_yaml_from_page "$1" "$2"
  page_run "$1" "kubectl apply -f $2"
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

# Run a command until its output contains the text, at most about 2 minutes.
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


# Where vulnerabilities are published
page=course-010-where-vulnerabilities-are-published.md
versions="$(page_run "$page" 'kubectl version')"
printf '%s\n' "$versions"
expect 'kubectl version prints the client version' "$versions" 'Client Version:'
expect 'kubectl version prints the server version' "$versions" 'Server Version:'
version_document="$(page_run "$page" 'kubectl get --raw /version')"
printf '%s\n' "$version_document"
server_version="$(python3 -c 'import json, sys; print(json.load(sys.stdin)["gitVersion"])' <<<"$version_document")"
expect 'gitVersion has the form v1.35.x' "$server_version" "$(text_from_page "$page" v1.35.)"
expect 'the version document has the Go version' "$version_document" '"goVersion"'
expect 'the version document has the build date' "$version_document" '"buildDate"'

# Inventory what the cluster runs
page=course-020-inventory-what-the-cluster-runs.md
nodes="$(page_run "$page" 'kubectl get nodes -o custom-columns=NAME:.metadata.name,KUBELET:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion,OS:.status.nodeInfo.osImage,KERNEL:.status.nodeInfo.kernelVersion')"
printf '%s\n' "$nodes"
expect_equal 'the cluster has three nodes' "$(awk 'NR > 1' <<<"$nodes" | wc -l | tr -d ' ')" 3
expect_equal 'the KUBELET column shows one value on all three nodes' "$(awk 'NR > 1 {print $2}' <<<"$nodes" | sort -u | wc -l | tr -d ' ')" 1
expect_equal 'every RUNTIME value starts with containerd://' "$(awk 'NR > 1 && $3 !~ /^containerd:\/\// {print $1}' <<<"$nodes")" ''
host_kernel="$(uname -r)"
expect 'the KERNEL column shows the host kernel' "$nodes" "$host_kernel"
system_images="$(page_run "$page" 'kubectl -n kube-system get pods -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[*].image')"
printf '%s\n' "$system_images"
server_minor="$(cut -d. -f1,2 <<<"$server_version")"
for component in kube-apiserver kube-controller-manager kube-scheduler kube-proxy; do
  expect "$component shows a Kubernetes version tag" "$(grep -E "^$component-" <<<"$system_images" | head -1)" ":$server_minor."
done
expect 'the etcd Pod shows its own image' "$(grep -E '^etcd-' <<<"$system_images")" /etcd:
expect 'the coredns Pod shows its own image' "$(grep -E '^coredns-' <<<"$system_images" | head -1)" /coredns
expect 'the network plugin Pod shows its own image' "$(grep -E '^kindnet-' <<<"$system_images" | head -1)" kindnet
workload_images="$(page_run "$page" "kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{\"\\t\"}{.metadata.name}{\"\\t\"}{range .spec.containers[*]}{.image}{\" \"}{end}{\"\\n\"}{end}'")"
grep -E '^(starfleet|outpost)' <<<"$workload_images" || true
expect 'the list has the probe image' "$(awk -F '\t' '$1 == "starfleet" && $2 ~ /^probe-/' <<<"$workload_images" | head -1)" docker.io/library/python:3.13-alpine
expect 'the list has the drifter image' "$(awk -F '\t' '$1 == "outpost" && $2 == "drifter"' <<<"$workload_images")" docker.io/library/busybox:1.37.0
expect 'the list includes the system Pods too' "$(awk -F '\t' '$1 == "kube-system" {print $2}' <<<"$workload_images")" kube-apiserver-
image_ids="$(page_run "$page" "kubectl -n starfleet get pods -l app=probe -o jsonpath='{range .items[*]}{.metadata.name}{\"\\t\"}{.status.containerStatuses[0].imageID}{\"\\n\"}{end}'")"
printf '%s\n' "$image_ids"
expect_equal 'two probe pods are listed' "$(grep -c '^probe-' <<<"$image_ids")" 2
expect_equal 'every imageID has a sha256 digest' "$(awk -F '\t' '$2 !~ /sha256:[0-9a-f]{64}$/ {print $1}' <<<"$image_ids")" ''
# The trivy command needs the trivy tool and network access. The page says it
# is shown to read and is not run in the playground, so it is left out.
on_page "$page" 'trivy image --severity HIGH,CRITICAL registry.k8s.io/kube-apiserver:v1.35.0'
save_yaml_from_page "$page" configmap-scratch-inventory.yaml
# The reader replaces the values in angle brackets with what they read above.
kubelet_control_plane="$(kubectl get node "$node_name" -o jsonpath='{.status.nodeInfo.kubeletVersion}')"
probe_image="$(kubectl -n starfleet get deployment probe -o jsonpath='{.spec.template.spec.containers[0].image}')"
sed -i.page -e "s|<SERVER_VERSION>|$server_version|" -e "s|<KUBELET_CONTROL_PLANE>|$kubelet_control_plane|" -e "s|<PROBE_IMAGE>|$probe_image|" configmap-scratch-inventory.yaml
page_run "$page" 'kubectl apply -f configmap-scratch-inventory.yaml'
# The page gives the check and the removal in sentences, not in command blocks.
text_from_page "$page" 'check the result with `kubectl -n starfleet get configmap scratch-inventory -o yaml`' >/dev/null
inventory="$(kubectl -n starfleet get configmap scratch-inventory -o yaml)"
expect "the record has the server version $server_version" "$inventory" "server-version: $server_version"
expect 'the record has the probe image' "$inventory" "probe-image: $probe_image"
text_from_page "$page" 'Remove the object with `kubectl -n starfleet delete configmap scratch-inventory`' >/dev/null
kubectl -n starfleet delete configmap scratch-inventory

# Triage a vulnerability and plan patch waves
page=course-030-triage-a-vulnerability-and-plan-patch-waves.md
second_worker="$(page_run "$page" 'kubectl get pods -A -o wide --field-selector spec.nodeName=astro-ats-032-playground-040-02-worker2')"
printf '%s\n' "$second_worker"
expect 'the second worker runs shuttle' "$second_worker" ' shuttle '
expect 'the second worker runs drifter' "$second_worker" ' drifter '
owners="$(page_run "$page" 'kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,OWNER:.metadata.ownerReferences[0].kind')"
expect_equal 'shuttle has no owner' "$(awk '$2 == "shuttle" {print $3}' <<<"$owners")" '<none>'
expect_equal 'drifter has no owner' "$(awk '$2 == "drifter" {print $3}' <<<"$owners")" '<none>'
expect_equal 'the bare Pods are only shuttle and drifter' "$(awk '$3 == "<none>" {print $2}' <<<"$owners" | sort | tr '\n' ' ')" 'drifter shuttle '
expect_equal 'the probe pods are owned by a ReplicaSet' "$(awk '$2 ~ /^probe-/ {print $3}' <<<"$owners" | sort -u)" ReplicaSet
expect_equal 'the kube-proxy pods are owned by a DaemonSet' "$(awk '$2 ~ /^kube-proxy-/ {print $3}' <<<"$owners" | sort -u)" DaemonSet
expect_equal 'the static Pod kube-apiserver shows Node' "$(awk '$2 ~ /^kube-apiserver-/ {print $3}' <<<"$owners")" Node
expect_equal 'no Pod on the first worker is a bare Pod' "$(kubectl get pods -A --field-selector "spec.nodeName=$worker_name" -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.metadata.ownerReferences[0].kind}{"\n"}{end}' | awk 'NF < 2')" ''
page_run "$page" 'kubectl label node astro-ats-032-playground-040-02-control-plane patch-wave=1'
page_run "$page" 'kubectl label node astro-ats-032-playground-040-02-worker patch-wave=2'
page_run "$page" 'kubectl label node astro-ats-032-playground-040-02-worker2 patch-wave=3'
wave_table="$(page_run "$page" 'kubectl get nodes -L patch-wave')"
printf '%s\n' "$wave_table"
expect 'the table has a PATCH-WAVE column' "$(head -1 <<<"$wave_table")" PATCH-WAVE
expect_equal 'the control plane is wave 1' "$(awk -v node="$node_name" '$1 == node {print $NF}' <<<"$wave_table")" 1
expect_equal 'the first worker is wave 2' "$(awk -v node="$worker_name" '$1 == node {print $NF}' <<<"$wave_table")" 2
expect_equal 'the second worker is wave 3' "$(awk -v node="${worker_name}2" '$1 == node {print $NF}' <<<"$wave_table")" 3
wave_two="$(page_run "$page" 'kubectl get nodes -l patch-wave=2')"
printf '%s\n' "$wave_two"
expect_equal 'wave 2 is the single first worker' "$(awk 'NR > 1 {print $1}' <<<"$wave_two")" "$worker_name"
# The page removes the labels with `kubectl label node <name> patch-wave-`; the
# reader types the node name, so loop over the three nodes.
text_from_page "$page" 'kubectl label node <name> patch-wave-' >/dev/null
for node in "$node_name" "$worker_name" "${worker_name}2"; do
  kubectl label node "$node" patch-wave-
done

# Playground guide
page=playground/docs/overview.md
# The guide first points KUBECONFIG at the playground with `astrona kubeconfig`.
# scripts/ci/test-playground.sh has already done that, so the export is left out.
page_run "$page" 'test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-040-02" || exit 1'
expect_equal 'the probe Deployment has two ready replicas' "$(kubectl -n starfleet get deployment probe -o jsonpath='{.status.readyReplicas}')" 2
expect_equal 'both bare pods run on the second worker' "$(kubectl get pod -A -l 'app in (shuttle,drifter)' -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u)" "${worker_name}2"

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
