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
cluster_name=astro-ats-032-playground-020-02
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


# Print the probe pods that still use the default ServiceAccount. A rollout
# leaves the old pods Terminating for a short time, and they are still listed.
probe_pods_on_default() {
  kubectl -n starfleet get pods -o custom-columns=NAME:.metadata.name,SERVICEACCOUNT:.spec.serviceAccountName --no-headers | awk '$1 ~ /^probe-/ && $2 == "default"'
}

# One ServiceAccount for each workload
page=course-01-one-serviceaccount-for-each-workload.md
pod_accounts="$(page_run "$page" 'kubectl -n starfleet get pods -o custom-columns=NAME:.metadata.name,SERVICEACCOUNT:.spec.serviceAccountName')"
printf '%s\n' "$pod_accounts"
expect_equal 'all three pods use the default ServiceAccount' "$(awk 'NR > 1 && $2 == "default"' <<<"$pod_accounts" | wc -l | tr -d ' ')" 3
accounts="$(page_run "$page" 'kubectl -n starfleet get serviceaccounts')"
printf '%s\n' "$accounts"
expect_equal 'the namespace has only the default ServiceAccount' "$(awk 'NR > 1 {print $1}' <<<"$accounts")" default
save_from_page "$page" serviceaccount-probe.yaml
page_run "$page" 'kubectl -n starfleet set serviceaccount deployment/probe probe'
page_run "$page" 'kubectl -n starfleet rollout status deployment/probe --timeout=180s'
for attempt in $(seq 1 40); do
  [[ -z "$(probe_pods_on_default)" ]] && break
  sleep 3
done
pod_accounts="$(page_run "$page" 'kubectl -n starfleet get pods -o custom-columns=NAME:.metadata.name,SERVICEACCOUNT:.spec.serviceAccountName')"
printf '%s\n' "$pod_accounts"
expect_equal 'both probe pods now use the probe ServiceAccount' "$(awk '$1 ~ /^probe-/ && $2 == "probe"' <<<"$pod_accounts" | wc -l | tr -d ' ')" 2
expect_equal 'no probe pod uses default any more' "$(awk '$1 ~ /^probe-/ && $2 != "probe"' <<<"$pod_accounts")" ''
expect_equal 'the shuttle pod still uses default' "$(awk '$1 == "shuttle" {print $2}' <<<"$pod_accounts")" default
token_listing="$(page_fails "$page" 'kubectl -n starfleet exec deploy/probe -- ls /var/run/secrets/kubernetes.io/serviceaccount')"
printf '%s\n' "$token_listing"
expect 'ls fails because the token directory does not exist' "$token_listing" 'No such file or directory'

# Grant only what the workload uses
page=course-02-grant-only-what-the-workload-uses.md
save_from_page "$page" rbac-shuttle-reader.yaml
# The page lists the six answers in this order.
text_from_page "$page" 'The answers are `yes`, `no`, `no`, `yes`, `no` and `no`.' >/dev/null
expect_equal 'shuttle-reader may get pods in starfleet' "$(page_run "$page" 'kubectl auth can-i get pods -n starfleet --as=system:serviceaccount:starfleet:shuttle-reader')" yes
expect_equal 'shuttle-reader may not delete pods' "$(page_fails "$page" 'kubectl auth can-i delete pods -n starfleet --as=system:serviceaccount:starfleet:shuttle-reader' | tail -1)" no
expect_equal 'shuttle-reader may not get Secrets' "$(page_fails "$page" 'kubectl auth can-i get secrets -n starfleet --as=system:serviceaccount:starfleet:shuttle-reader' | tail -1)" no
expect_equal 'shuttle-reader may get the ConfigMap probe-code' "$(page_run "$page" 'kubectl auth can-i get configmap/probe-code -n starfleet --as=system:serviceaccount:starfleet:shuttle-reader')" yes
expect_equal 'shuttle-reader may not get another ConfigMap' "$(page_fails "$page" 'kubectl auth can-i get configmap/other -n starfleet --as=system:serviceaccount:starfleet:shuttle-reader' | tail -1)" no
expect_equal 'shuttle-reader may not get pods in outpost' "$(page_fails "$page" 'kubectl auth can-i get pods -n outpost --as=system:serviceaccount:starfleet:shuttle-reader' | tail -1)" no
save_from_page "$page" pod-shuttle-reader.yaml
page_run "$page" 'kubectl -n starfleet wait --for=condition=Ready pod/shuttle-reader --timeout=90s'
token_listing="$(page_run "$page" 'kubectl -n starfleet exec shuttle-reader -- ls /var/run/secrets/kubernetes.io/serviceaccount')"
printf '%s\n' "$token_listing"
expect 'the token directory has ca.crt' "$token_listing" ca.crt
expect 'the token directory has namespace' "$token_listing" namespace
expect 'the token directory has token' "$token_listing" token
binding="$(page_run "$page" 'kubectl -n starfleet describe rolebinding shuttle-reader')"
printf '%s\n' "$binding"
expect 'the binding names the Role shuttle-reader' "$(grep -A2 '^Role:' <<<"$binding")" 'shuttle-reader'
expect_equal 'the binding has one ServiceAccount subject' "$(grep -cE '^ +ServiceAccount +shuttle-reader +starfleet' <<<"$binding")" 1

# Clean up the default ServiceAccount
page=course-03-clean-up-the-default-serviceaccount.md
expect_equal 'default may get pods before the cleanup' "$(page_run "$page" 'kubectl auth can-i get pods -n starfleet --as=system:serviceaccount:starfleet:default')" yes
default_rules="$(page_run "$page" 'kubectl auth can-i --list -n starfleet --as=system:serviceaccount:starfleet:default')"
printf '%s\n' "$default_rules"
expect 'the rule list shows get, list and watch on pods' "$(grep -E '^pods ' <<<"$default_rules")" '[get list watch]'
bindings="$(page_run "$page" 'kubectl -n starfleet get rolebindings -o wide')"
printf '%s\n' "$bindings"
expect 'the wide output has a SERVICEACCOUNTS column' "$(head -1 <<<"$bindings")" SERVICEACCOUNTS
expect 'default-pod-access names starfleet/default' "$(grep '^default-pod-access ' <<<"$bindings")" starfleet/default
cluster_bindings="$(page_run "$page" 'kubectl get clusterrolebindings -o wide')"
expect 'the cluster-wide list has a SERVICEACCOUNTS column' "$(head -1 <<<"$cluster_bindings")" SERVICEACCOUNTS
expect 'most cluster-wide rows are system bindings' "$cluster_bindings" 'system:'
page_run "$page" 'kubectl -n starfleet delete rolebinding default-pod-access'
page_run "$page" "kubectl -n starfleet patch serviceaccount default -p '{\"automountServiceAccountToken\": false}'"
expect_equal 'default may no longer get pods' "$(page_fails "$page" 'kubectl auth can-i get pods -n starfleet --as=system:serviceaccount:starfleet:default' | tail -1)" no
page_run "$page" 'for namespace in starfleet outpost; do
  kubectl -n "$namespace" patch serviceaccount default -p '"'"'{"automountServiceAccountToken": false}'"'"'
done'
automount_table="$(page_run "$page" 'kubectl get serviceaccounts -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,AUTOMOUNT:.automountServiceAccountToken')"
printf '%s\n' "$automount_table" | grep -E '^(starfleet|outpost) ' || true
expect_equal 'the starfleet default account shows false' "$(awk '$1 == "starfleet" && $2 == "default" {print $3}' <<<"$automount_table")" false
expect_equal 'the outpost default account shows false' "$(awk '$1 == "outpost" && $2 == "default" {print $3}' <<<"$automount_table")" false
expect_equal 'an account that never set the field shows <none>' "$(awk '$1 == "starfleet" && $2 == "shuttle-reader" {print $3}' <<<"$automount_table")" '<none>'

# Playground guide
page=playground/docs/overview.md
# The guide first points KUBECONFIG at the playground with `astrona kubeconfig`.
# scripts/ci/test-playground.sh has already done that, so the export is left out.
page_run "$page" 'test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-020-02" || exit 1'
expect_equal 'the probe Deployment has two ready replicas' "$(kubectl -n starfleet get deployment probe -o jsonpath='{.status.readyReplicas}')" 2
expect_equal 'the Role pod-access still exists after the cleanup' "$(kubectl -n starfleet get role pod-access -o name)" role.rbac.authorization.k8s.io/pod-access
expect_equal 'the pod drifter runs in outpost' "$(kubectl -n outpost get pod drifter -o jsonpath='{.status.phase}')" Running

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
