#!/usr/bin/env bash
# Runs the commands that the module pages and the playground guide teach
# inside the playground VM and fails when one of them does not give the result
# the page describes. Every command is first looked up on its page and then run
# exactly as the page writes it, and every YAML file comes from the page.
# scripts/ci/test-playground.sh copies the pages and this folder into the VM
# and runs the script there as the student user. The VM is the only node,
# controlplane, so node commands use sudo directly. No page step changes the
# API server or the kubelet, so nothing here restarts a component.
set -euo pipefail
# Keep set -e inside $(...), so a failed page lookup also stops a captured command.
shopt -s inherit_errexit 2>/dev/null || true
cluster_name=astro-ats-032-playground-030-01
if [[ "$(kubectl config current-context)" != "${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@$cluster_name}" ]]; then
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

# Write the YAML block that follows "Save this as `<file>`" on a page to <file>.
save_yaml_from_page() {
  python3 - "$module_directory/$1" "$2" "$work_directory/$2" <<'PY'
import re, sys
page, name, target = sys.argv[1:]
text = open(page).read()
match = re.search(r'as `' + re.escape(name) + r'`.*?```yaml\n(.*?)```', text, re.S)
if not match:
    sys.exit('no YAML block for ' + name + ' in ' + page)
open(target, 'w').write(match.group(1))
PY
}

# Print the ```text block that follows the first ```sh block containing the
# command on a page, before the next ```sh block: the output the page shows
# for that command.
output_from_page() {
  python3 - "$module_directory/$1" "$2" <<'PY'
import re, sys
page, command = sys.argv[1:]
text = open(page).read()
for match in re.finditer(r'```sh\n(.*?)```((?:(?!```sh\n).)*?)```text\n(.*?)```', text, re.S):
    if command in match.group(1):
        print(match.group(3), end='')
        break
else:
    sys.exit('no output block after ' + command + ' in ' + page)
PY
}

# Print a phrase that the page states, and fail when the page no longer has it.
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

# Print the probe Pods with their ServiceAccount until no Pod of the old
# ReplicaSet (ServiceAccount default) is left, at most about 2 minutes.
wait_for_old_probe_pods_gone() {
  local output='' attempt
  on_page "$1" "$2" || exit 1
  for attempt in $(seq 1 40); do
    output="$(page_run "$1" "$2" 2>/dev/null || true)"
    [[ "$output" != *default* ]] && [[ "$output" == *lister* ]] && break
    sleep 3
  done
  printf '%s\n' "$output"
}

# The call_api helper as the pages define it. The helper text is the same on
# the first two pages, and each page's copy is looked up on that page.
call_api_definition="$(cat <<'CMD'
call_api() {
  kubectl -n starfleet exec -i deployment/probe -- python - "$@" <<'PY'
import sys, ssl, urllib.request, urllib.error
from pathlib import Path
path, mode = sys.argv[1], sys.argv[2]
root = Path('/var/run/secrets/kubernetes.io/serviceaccount')
ctx = ssl.create_default_context(cafile=str(root / 'ca.crt'))
req = urllib.request.Request('https://kubernetes.default.svc' + path)
if mode == 'token':
    req.add_header('Authorization', 'Bearer ' + (root / 'token').read_text())
try:
    print(urllib.request.urlopen(req, context=ctx, timeout=5).status)
except urllib.error.HTTPError as e:
    print(e.code)
PY
}
CMD
)"

# Playground guide. It runs first: it describes the starting state, and the
# second page later moves probe to another ServiceAccount.
# `astrona ssh astro-ats-032-playground-030-01` is left out: it runs on the
# learner's machine, and this script already runs in that shell.
page=playground/docs/overview.md
expect_equal 'the context is the playground cluster' "$(page_run "$page" 'kubectl config current-context')" "$(text_from_page "$page" "kubernetes-admin@$cluster_name")"
nodes="$(page_run "$page" 'kubectl get nodes')"
printf '%s\n' "$nodes"
expect 'the only node is controlplane and it is Ready' "$(grep -E '^controlplane ' <<<"$nodes" || true)" Ready
expect 'controlplane has the control-plane role' "$(grep -E '^controlplane ' <<<"$nodes" || true)" control-plane
expect 'the node runs Kubernetes v1.35' "$(grep -E '^controlplane ' <<<"$nodes" || true)" ' v1.35.'
expect_equal 'the cluster has one node' "$(grep -vc '^NAME' <<<"$nodes" || true)" 1
expect_equal 'probe has two ready replicas' "$(kubectl -n starfleet get deployment probe -o jsonpath='{.status.readyReplicas}')" 2
expect_equal 'starfleet has the Service probe' "$(kubectl -n starfleet get service probe -o jsonpath='{.metadata.name}')" probe
expect_equal 'shuttle runs in starfleet' "$(kubectl -n starfleet get pod shuttle -o jsonpath='{.status.phase}')" Running
expect_equal 'drifter runs in outpost' "$(kubectl -n outpost get pod drifter -o jsonpath='{.status.phase}')" Running
expect_equal 'every example Pod uses the default ServiceAccount' "$(kubectl get pods -n starfleet -o jsonpath='{.items[*].spec.serviceAccountName}' | tr ' ' '\n' | sort -u) $(kubectl get pods -n outpost -o jsonpath='{.items[*].spec.serviceAccountName}')" 'default default'
expect 'the API server manifest is on the node' "$(sudo ls /etc/kubernetes/manifests)" kube-apiserver.yaml
expect 'the kubelet configuration is on the node' "$(sudo ls /var/lib/kubelet)" config.yaml

# How an API request is checked
page=course-01-how-an-api-request-is-checked.md
page_run "$page" "$call_api_definition"
expect_equal '/version without a credential gives 200' "$(page_run "$page" 'call_api /version anon')" 200
expect_equal 'listing Pods without a credential gives 403' "$(page_run "$page" 'call_api /api/v1/namespaces/starfleet/pods anon')" 403
expect_equal '/version with the token gives 200' "$(page_run "$page" 'call_api /version token')" 200
expect_equal 'listing Pods with the default token gives 403' "$(page_run "$page" 'call_api /api/v1/namespaces/starfleet/pods token')" 403
expect_equal 'can-i says the default ServiceAccount may not list Pods' "$(page_fails "$page" 'kubectl auth can-i list pods -n starfleet --as=system:serviceaccount:starfleet:default')" no
default_rules="$(page_run "$page" 'kubectl auth can-i --list -n starfleet --as=system:serviceaccount:starfleet:default')"
printf '%s\n' "$default_rules"
# Every line that the page shows is in the live list. The column widths
# depend on the longest entry, so compare with the spaces squeezed.
page_rules="$(output_from_page "$page" 'kubectl auth can-i --list -n starfleet')"
squeezed_rules="$(tr -s ' ' <<<"$default_rules")"
while read -r rule_line; do
  squeezed_line="$(tr -s ' ' <<<"$rule_line")"
  expect "the rule list has: $squeezed_line" "$squeezed_rules" "$squeezed_line"
done <<<"$page_rules"
for read_only_path in /livez /readyz /version; do
  expect "the rule list has the read-only path $read_only_path" "$default_rules" "[$read_only_path]"
done
expect_no 'no rule names pods' "$default_rules" pods

# A narrow workload identity
page=course-02-a-narrow-workload-identity.md
save_yaml_from_page "$page" serviceaccount-lister.yaml
created="$(page_run "$page" 'kubectl apply -f serviceaccount-lister.yaml')"
expect_equal 'apply creates the three objects' "$created" "$(output_from_page "$page" 'kubectl apply -f serviceaccount-lister.yaml')"
expect_equal 'lister may list Services in starfleet' "$(page_run "$page" 'kubectl auth can-i list services -n starfleet --as=system:serviceaccount:starfleet:lister')" yes
expect_equal 'lister may not list Pods' "$(page_fails "$page" 'kubectl auth can-i list pods -n starfleet --as=system:serviceaccount:starfleet:lister')" no
expect_equal 'lister may not list Services in outpost' "$(page_fails "$page" 'kubectl auth can-i list services -n outpost --as=system:serviceaccount:starfleet:lister')" no
page_run "$page" 'kubectl -n starfleet set serviceaccount deployment/probe lister'
rollout="$(page_run "$page" 'kubectl -n starfleet rollout status deployment/probe --timeout=180s')"
printf '%s\n' "$rollout"
expect_equal 'the rollout ends with the success line' "$(tail -1 <<<"$rollout")" "$(text_from_page "$page" 'deployment "probe" successfully rolled out')"
# The page runs the command again after the 30 second grace period; wait
# until the old rows are gone.
service_accounts="$(wait_for_old_probe_pods_gone "$page" 'kubectl -n starfleet get pods -l app=probe -o custom-columns=NAME:.metadata.name,SA:.spec.serviceAccountName')"
printf '%s\n' "$service_accounts"
expect_equal 'only the two lister rows remain' "$(grep -vc '^NAME' <<<"$service_accounts" || true)" 2
expect_equal 'both rows use lister' "$(awk 'NR > 1 {print $2}' <<<"$service_accounts" | sort -u)" lister
page_run "$page" "$call_api_definition"
expect_equal 'listing Services in starfleet with the lister token gives 200' "$(page_run "$page" 'call_api /api/v1/namespaces/starfleet/services token')" 200
expect_equal 'listing Pods with the lister token gives 403' "$(page_run "$page" 'call_api /api/v1/namespaces/starfleet/pods token')" 403
expect_equal 'listing Secrets with the lister token gives 403' "$(page_run "$page" 'call_api /api/v1/namespaces/starfleet/secrets token')" 403
expect_equal 'listing Services in outpost with the lister token gives 403' "$(page_run "$page" 'call_api /api/v1/namespaces/outpost/services token')" 403

# Hardening the endpoint and the kubelet
page=course-03-hardening-the-endpoint-and-the-kubelet.md
apiserver_flags_command="$(cat <<'CMD'
kubectl -n kube-system get pod -l component=kube-apiserver -o jsonpath='{range .items[0].spec.containers[0].command[*]}{@}{"\n"}{end}'
CMD
)"
apiserver_flags="$(page_run "$page" "$apiserver_flags_command")"
printf '%s\n' "$apiserver_flags"
# The advertise address is the IP address of the VM, so leave that line out.
expect_equal 'the flag list is the one the page shows, apart from the advertise address' "$(grep -v '^--advertise-address=' <<<"$apiserver_flags" || true)" "$(output_from_page "$page" 'get pod -l component=kube-apiserver' | grep -v '^--advertise-address=')"
expect 'the authorization mode is Node,RBAC' "$apiserver_flags" "$(text_from_page "$page" '--authorization-mode=Node,RBAC')"
expect 'NodeRestriction is enabled' "$apiserver_flags" "$(text_from_page "$page" '--enable-admission-plugins=NodeRestriction')"
for missing_flag in --anonymous-auth --audit- --profiling --tls-min-version; do
  expect_no "the flag list has no $missing_flag" "$apiserver_flags" "$missing_flag"
done
manifest_flags="$(page_run "$page" "sudo grep -E 'anonymous-auth|authorization-mode|admission-plugins|audit|profiling|tls-min' /etc/kubernetes/manifests/kube-apiserver.yaml")"
expect_equal 'the manifest holds only the two flags' "$manifest_flags" "$(output_from_page "$page" 'sudo grep -E')"
kubelet_settings="$(page_run "$page" "sudo grep -n -A1 -E 'anonymous:|^authorization:|readOnlyPort' /var/lib/kubelet/config.yaml")"
expect_equal 'the kubelet file has anonymous off and mode Webhook' "$kubelet_settings" "$(output_from_page "$page" 'sudo grep -n -A1')"
expect_no 'the kubelet file has no readOnlyPort line' "$kubelet_settings" readOnlyPort
configz_command="$(cat <<'CMD'
kubectl get --raw /api/v1/nodes/controlplane/proxy/configz | jq '.kubeletconfig | {anonymous: .authentication.anonymous.enabled, webhook: .authentication.webhook.enabled, mode: .authorization.mode, readOnlyPort}'
CMD
)"
expect_equal 'the running kubelet reports the four settings' "$(page_run "$page" "$configz_command")" "$(output_from_page "$page" 'proxy/configz')"
node_ip_command="$(cat <<'CMD'
node_ip=$(kubectl get node controlplane -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
CMD
)"
page_run "$page" "$node_ip_command"
kubelet_port="$(page_run "$page" "curl -sk -o /dev/null -w '%{http_code}\n' https://\$node_ip:10250/pods")"
# curl fails on the closed port, so run the page's line with set -e off, as
# in an interactive shell, where the echo still prints the exit code.
read_only_port="$(set +e; page_run "$page" "curl -s -o /dev/null -w '%{http_code}\n' http://\$node_ip:10255/pods; echo \"curl exit code: \$?\"")"
expect_equal 'port 10250 answers 401 and port 10255 is closed' "$kubelet_port"$'\n'"$read_only_port" "$(output_from_page "$page" ':10250/pods')"

# audit-policy.yaml is a reference file: the page does not apply it, so only
# check that its YAML is on the page.
save_yaml_from_page "$page" audit-policy.yaml
expect 'the reference audit policy logs Secrets at Metadata level' "$(cat audit-policy.yaml)" 'level: Metadata'
# The page names this check in its text, for after a manifest edit. The
# playground makes no edit, so the API server Pod must simply be Running.
text_from_page "$page" 'check it with `kubectl -n kube-system get pod -l component=kube-apiserver`' >/dev/null
expect 'the API server Pod is Running' "$(kubectl -n kube-system get pod -l component=kube-apiserver)" Running

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
