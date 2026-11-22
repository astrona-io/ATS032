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
cluster_name=astro-ats-032-playground-010-03
context="${ASTRONA_KUBE_CONTEXT:-kind-$cluster_name}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
# The pages save files in the current folder, so work in an empty one.
cd "$work_directory"

# A page lookup can run inside $(...) in the argument of a check, where its
# exit does not stop the script. It leaves this file, and the next check stops.
lookup_failed="$work_directory/lookup-failed"
stop_after_failed_lookup() {
  [[ ! -e "$lookup_failed" ]] || { printf 'FAIL: a page lookup failed, see the message above\n' >&2; exit 1; }
}

# Fail unless the page has this exact command in one of its ```sh blocks.
on_page() {
  python3 - "$module_directory/$1" "$2" <<'PY' || { : >"$lookup_failed"; return 1; }
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
  python3 - "$module_directory/$1" "$2" <<'PY' || { : >"$lookup_failed"; return 1; }
import sys
page, phrase = sys.argv[1:]
if ' '.join(phrase.split()) not in ' '.join(open(page).read().split()):
    sys.exit('the page ' + page + ' does not say: ' + phrase)
print(phrase, end='')
PY
}

checks=0
expect() {
  stop_after_failed_lookup
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == *"$3"* ]] || { printf 'FAIL: %s\nwanted: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

expect_equal() {
  stop_after_failed_lookup
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == "$3" ]] || { printf 'FAIL: %s\nwanted exactly: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

expect_no() {
  stop_after_failed_lookup
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

# Run a `kubectl auth can-i` command from the page and check its answer.
# `yes` exits with status 0 and `no` with status 1, as the pages say, so a
# `no` command runs through page_fails.
expect_can_i() {
  local page="$1" command="$2" wanted="$3" description="$4" output
  if [[ "$wanted" == yes ]]; then
    output="$(page_run "$page" "$command")" || { printf 'FAIL: %s\nthe command exited non-zero, the page says yes: %s\n' "$description" "$command" >&2; exit 1; }
  else
    output="$(page_fails "$page" "$command")"
  fi
  printf '%s\n' "$output"
  expect_equal "$description" "$(tail -n 1 <<<"$output")" "$wanted"
}

observer='--as=anyone --as-group=outpost-observers'
crew='--as=jane --as-group=outpost-crew'

# Users, groups and ServiceAccounts as subjects
page=course-01-users-groups-and-serviceaccounts-as-subjects.md
page_run "$page" 'openssl req -new -newkey rsa:2048 -nodes -keyout jane.key -subj "/CN=jane/O=outpost-observers" -out jane.csr'
request_subject="$(page_run "$page" 'openssl req -in jane.csr -noout -subject')"
printf '%s\n' "$request_subject"
expect 'the request subject has the CN jane' "$(tr -d ' ' <<<"$request_subject")" CN=jane
expect 'the request subject has the O outpost-observers' "$(tr -d ' ' <<<"$request_subject")" O=outpost-observers
save_from_page "$page" rolebinding-observers.yaml
expect 'the API server accepts a binding for the user ghost' "$(kubectl -n outpost get rolebinding observers -o jsonpath='{.subjects[0].name}')" ghost
expect_can_i "$page" 'kubectl auth can-i list pods -n outpost --as=ghost' yes 'the user ghost may list Pods'
expect_can_i "$page" "kubectl auth can-i list pods -n outpost $observer" yes 'any member of outpost-observers may list Pods'
expect_can_i "$page" 'kubectl auth can-i list pods -n outpost --as=system:serviceaccount:starfleet:probe' yes 'the ServiceAccount probe may list Pods'
expect_can_i "$page" 'kubectl auth can-i list pods -n outpost --as=ghosts' no 'the user ghosts, one letter different, may not'
# The imperative `kubectl create rolebinding observers ...` is only in the
# prose, not in a command block, so it is not run.
page_run "$page" 'kubectl -n outpost delete rolebinding observers'

# Built-in and aggregated ClusterRoles
page=course-02-built-in-and-aggregated-clusterroles.md
default_bindings="$(page_run "$page" 'kubectl get clusterrolebinding cluster-admin system:basic-user system:discovery -o wide')"
printf '%s\n' "$default_bindings"
expect 'the wide output has a GROUPS column' "$(head -n 1 <<<"$default_bindings")" "$(text_from_page "$page" GROUPS)"
expect 'cluster-admin is bound to system:masters' "$(grep -E '^cluster-admin[[:space:]]' <<<"$default_bindings" || true)" system:masters
expect 'system:basic-user is bound to system:authenticated' "$(grep -E '^system:basic-user[[:space:]]' <<<"$default_bindings" || true)" system:authenticated
expect 'system:discovery is bound to system:authenticated' "$(grep -E '^system:discovery[[:space:]]' <<<"$default_bindings" || true)" system:authenticated
view_selector="$(page_run "$page" "kubectl get clusterrole view -o jsonpath='{.aggregationRule.clusterRoleSelectors[0].matchLabels}'")"
printf '%s\n' "$view_selector"
expect 'the view selector has the label key' "$view_selector" "$(text_from_page "$page" rbac.authorization.k8s.io/aggregate-to-view)"
expect 'the view selector has the value true' "$view_selector" '":"true"'
save_from_page "$page" clusterroles-outpost-reader.yaml
# The page says to repeat the first check while the aggregation controller
# fills in the rules, so wait for its yes (bounded).
first_check="kubectl auth can-i list pods -n outpost $observer"
on_page "$page" "$first_check"
wait_for_output yes eval "$first_check" >/dev/null
expect_can_i "$page" "$first_check" yes 'the aggregated role lets outpost-observers list Pods'
expect_can_i "$page" "kubectl auth can-i list services -n outpost $observer" no 'the aggregated role has no rule for Services yet'
save_yaml_from_page "$page" clusterrole-outpost-reader-services.yaml
page_run "$page" 'kubectl apply -f clusterrole-outpost-reader-services.yaml'
# The page says to wait a few seconds before the question, so wait (bounded).
services_check="kubectl auth can-i list services -n outpost $observer"
on_page "$page" "$services_check"
wait_for_output yes eval "$services_check" >/dev/null
expect_can_i "$page" "$services_check" yes 'the second labelled role adds Services without a change to the binding'
expect 'the controller wrote the services rule into outpost-reader' "$(kubectl get clusterrole outpost-reader -o jsonpath='{.rules[*].resources}')" services
page_run "$page" 'kubectl delete -f clusterrole-outpost-reader-services.yaml -f clusterroles-outpost-reader.yaml'

# Remove wildcards and narrow rules
page=course-03-remove-wildcards-and-narrow-rules.md
expect_can_i "$page" "kubectl auth can-i get secrets -n outpost $crew" yes 'the wildcard lets the crew read Secrets'
expect_can_i "$page" "kubectl auth can-i create rolebindings.rbac.authorization.k8s.io -n outpost $crew" yes 'the wildcard lets the crew create bindings'
wildcard_roles="$(page_run "$page" "kubectl get roles --all-namespaces -o yaml | grep -n -B8 \"'\\*'\"")"
printf '%s\n' "$wildcard_roles"
expect 'the search shows the Role name crew-operator' "$wildcard_roles" 'name: crew-operator'
expect 'the search shows the namespace outpost' "$wildcard_roles" 'namespace: outpost'
wildcard_count="$(page_run "$page" "kubectl get clusterroles -o yaml | grep -c \"'\\*'\"")"
printf '%s\n' "$wildcard_count"
expect_equal 'the ClusterRole search prints a count above zero' "$((wildcard_count > 0))" 1
core_resources="$(page_run "$page" 'kubectl api-resources --namespaced=true --api-group="" -o name')"
for resource in configmaps pods secrets services; do
  expect "the core group list has $resource" "$(grep -x "$resource" <<<"$core_resources" || true)" "$resource"
done
save_from_page "$page" role-crew-operator.yaml
expect_can_i "$page" "kubectl auth can-i list pods -n outpost $crew" yes 'the crew may still list Pods'
expect_can_i "$page" "kubectl auth can-i delete configmaps -n outpost $crew" yes 'the crew may still delete ConfigMaps'
expect_can_i "$page" "kubectl auth can-i get secrets -n outpost $crew" no 'the crew may no longer read Secrets'
expect_can_i "$page" "kubectl auth can-i delete pods -n outpost $crew" no 'the crew may no longer delete Pods'
expect_can_i "$page" "kubectl auth can-i create pods --subresource=exec -n outpost $crew" no 'the crew may no longer create pods/exec'
expect_can_i "$page" "kubectl auth can-i create rolebindings.rbac.authorization.k8s.io -n outpost $crew" no 'the crew may no longer create bindings'
expect 'the group binding did not change' "$(kubectl -n outpost get rolebinding outpost-crew-operator -o jsonpath='{.roleRef.name} {.subjects[0].name}')" 'crew-operator outpost-crew'

# Playground guide
page=playground/docs/overview.md
# `export KUBECONFIG="$(astrona kubeconfig ...)"` is left out: the CI script
# already sets KUBECONFIG to this playground's file. The context check runs.
page_run "$page" 'test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-010-03" || exit 1'
expect_equal 'the guide context check passes' "$(kubectl config current-context)" kind-astro-ats-032-playground-010-03

stop_after_failed_lookup
printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
