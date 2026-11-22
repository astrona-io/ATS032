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
cluster_name=astro-ats-032-playground-010-01
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

# Print the rows of a rule table (from `kubectl describe role` or
# `kubectl auth can-i --list`) whose first column is the given resource.
rule_rows() {
  grep -E "^[[:space:]]*$2[[:space:]]" <<<"$1" || true
}

shuttle='--as=system:serviceaccount:starfleet:shuttle'

# Roles, bindings and scope
page=course-01-roles-bindings-and-scope.md
expect 'the shuttle ServiceAccount exists' "$(page_run "$page" 'kubectl -n starfleet get serviceaccount shuttle')" shuttle
expect_can_i "$page" "kubectl auth can-i list configmaps -n outpost $shuttle" no 'shuttle cannot list ConfigMaps in outpost before any grant'
save_from_page "$page" role-configmap-reader.yaml
expect_can_i "$page" "kubectl auth can-i list configmaps -n outpost $shuttle" yes 'shuttle can list ConfigMaps in outpost'
expect_can_i "$page" "kubectl auth can-i delete configmaps -n outpost $shuttle" no 'the Role does not include delete'
expect_can_i "$page" "kubectl auth can-i list configmaps -n starfleet $shuttle" no 'the binding does not reach starfleet'
expect_can_i "$page" "kubectl auth can-i list secrets -n outpost $shuttle" no 'the rule does not include Secrets'
# The two `kubectl create ... --dry-run=client -o yaml` commands are only in a
# tip in the prose, not in a command block, so they are not run.

# ClusterRoles, reuse and escalation prevention
page=course-02-clusterroles-reuse-and-escalation-prevention.md
builtin_roles="$(page_run "$page" 'kubectl get clusterrole view edit admin cluster-admin')"
printf '%s\n' "$builtin_roles"
for role in view edit admin cluster-admin; do
  expect "the built-in ClusterRole $role is listed" "$(awk '{print $1}' <<<"$builtin_roles")" "$role"
done
view_rules="$(page_run "$page" 'kubectl describe clusterrole view')"
expect 'view has a row for pods with get, list and watch' "$(rule_rows "$view_rules" pods)" '[get list watch]'
expect 'view has a row for services' "$(rule_rows "$view_rules" services)" services
expect 'view has a row for configmaps' "$(rule_rows "$view_rules" configmaps)" configmaps
expect_equal 'view has no row for secrets' "$(rule_rows "$view_rules" secrets)" ''
save_from_page "$page" rolebinding-shuttle-view.yaml
expect_can_i "$page" "kubectl auth can-i list pods -n outpost $shuttle" yes 'view lets shuttle list Pods in outpost'
expect_can_i "$page" "kubectl auth can-i get secrets -n outpost $shuttle" no 'view has no rule for Secrets'
expect_can_i "$page" "kubectl auth can-i list pods -n starfleet $shuttle" no 'the RoleBinding to view exists only in outpost'
save_from_page "$page" role-role-manager.yaml
# copy-reader asks for `get configmaps`, which shuttle holds through the
# configmap-reader grant of the page before.
expect 'shuttle may create a Role inside its own permissions' "$(page_run "$page" "kubectl create role copy-reader --verb=get --resource=configmaps -n outpost $shuttle")" 'copy-reader created'
escalation="$(page_fails "$page" "kubectl create role secret-reader --verb=get --resource=secrets -n outpost $shuttle")"
printf '%s\n' "$escalation"
# kubectl prints the reason in lower case ("is forbidden"), so compare without case.
expect 'the Role with Secrets is Forbidden' "$(tr '[:upper:]' '[:lower:]' <<<"$escalation")" "$(text_from_page "$page" Forbidden | tr '[:upper:]' '[:lower:]')"
expect 'the error says shuttle attempts to grant permissions it does not hold' "$escalation" "$(text_from_page "$page" 'attempting to grant RBAC permissions not currently held')"

# Additive grants, dangerous verbs and auditing access
page=course-03-additive-grants-dangerous-verbs-and-auditing-access.md
# The binding shuttle-view exists from the page before, so the page's fallback
# command `kubectl -n outpost create rolebinding shuttle-view ...` (prose only)
# is not needed.
expect 'the RoleBinding shuttle-view exists at the start of the page' "$(kubectl -n outpost get rolebinding shuttle-view -o name)" shuttle-view
save_from_page "$page" role-pod-lister.yaml
page_run "$page" 'kubectl -n outpost delete rolebinding shuttle-view'
expect_can_i "$page" "kubectl auth can-i list pods -n outpost $shuttle" yes 'shuttle-pod-lister still allows listing Pods'
page_run "$page" 'kubectl -n outpost delete rolebinding shuttle-pod-lister'
expect_can_i "$page" "kubectl auth can-i list pods -n outpost $shuttle" no 'no binding lets shuttle list Pods any more'
shuttle_rules="$(page_run "$page" "kubectl auth can-i --list -n outpost $shuttle")"
printf '%s\n' "$shuttle_rules"
for column in Resources 'Non-Resource URLs' 'Resource Names' Verbs; do
  expect "the rule table has the column $column" "$(head -n 1 <<<"$shuttle_rules")" "$(text_from_page "$page" "$column")"
done
expect 'the table has the rule that lets every identity ask about its own permissions' "$shuttle_rules" selfsubjectaccessreviews.authorization.k8s.io
expect 'the table has the configmap-reader grant' "$(rule_rows "$shuttle_rules" configmaps)" '[get list]'
expect 'the table has the role-manager grant' "$shuttle_rules" roles.rbac.authorization.k8s.io
expect_equal 'the table has no rule for pods any more' "$(rule_rows "$shuttle_rules" pods)" ''
role_bindings="$(page_run "$page" 'kubectl get rolebindings -n outpost -o wide')"
printf '%s\n' "$role_bindings"
expect 'the wide list has a ROLE column' "$(head -n 1 <<<"$role_bindings")" ROLE
expect 'the wide list has a SERVICEACCOUNTS column' "$(head -n 1 <<<"$role_bindings")" SERVICEACCOUNTS
expect 'the binding to configmap-reader names starfleet/shuttle' "$(grep shuttle-configmap-reader <<<"$role_bindings" || true)" starfleet/shuttle
expect_no 'the deleted binding shuttle-view is gone' "$role_bindings" shuttle-view
cluster_bindings="$(page_run "$page" 'kubectl get clusterrolebindings -o wide')"
expect 'the wide list has a GROUPS column' "$(head -n 1 <<<"$cluster_bindings")" GROUPS
expect 'cluster-admin is bound to the group system:masters' "$(grep -E '^cluster-admin[[:space:]]' <<<"$cluster_bindings" || true)" system:masters

# Playground guide
page=playground/docs/overview.md
# `export KUBECONFIG="$(astrona kubeconfig ...)"` is left out: the CI script
# already sets KUBECONFIG to this playground's file. The context check runs.
page_run "$page" 'test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-010-01" || exit 1'
expect_equal 'the guide context check passes' "$(kubectl config current-context)" kind-astro-ats-032-playground-010-01

stop_after_failed_lookup
printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
