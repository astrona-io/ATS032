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
cluster_name=astro-ats-032-playground-010-02
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

scout='--as=system:serviceaccount:starfleet:scout'
shuttle='--as=system:serviceaccount:starfleet:shuttle'
crew='--as=jane --as-group=starfleet-crew'

# Ask the authorizer precisely
page=course-01-ask-the-authorizer-precisely.md
expect_can_i "$page" "kubectl auth can-i get secrets -n outpost $scout" yes 'edit lets scout read Secrets'
expect_can_i "$page" "kubectl auth can-i create rolebindings.rbac.authorization.k8s.io -n outpost $scout" no 'edit cannot create bindings'
expect_can_i "$page" "kubectl auth can-i get nodes $scout" no 'the grant has no rule for nodes'
expect_can_i "$page" "kubectl auth can-i update configmaps/scout-report -n outpost $scout" yes 'scout may update the ConfigMap scout-report'
expect_can_i "$page" "kubectl auth can-i create pods/exec -n outpost $scout" yes 'scout may create pods/exec'
expect_can_i "$page" "kubectl auth can-i list pods --all-namespaces $scout" yes 'scout may list Pods in every namespace'
expect_can_i "$page" "kubectl auth can-i list pods --all-namespaces $shuttle" no 'shuttle has no cluster-wide grant'
expect_can_i "$page" "kubectl auth can-i get /version $shuttle" yes 'every authenticated identity may read /version'
expect_can_i "$page" "kubectl auth can-i list pods -n outpost $crew" yes 'the group starfleet-crew may list Pods in outpost'
expect_can_i "$page" 'kubectl auth can-i list pods -n outpost --as=jane' no 'the user jane alone has no grant'
whoami="$(page_run "$page" "kubectl auth whoami $crew")"
printf '%s\n' "$whoami"
expect 'whoami shows the user name jane' "$(grep -i '^username' <<<"$whoami" || true)" jane
expect 'whoami shows the group starfleet-crew' "$(grep -i '^groups' <<<"$whoami" || true)" starfleet-crew
expect 'whoami shows the group system:authenticated' "$(grep -i '^groups' <<<"$whoami" || true)" system:authenticated

# Find every grant that reaches an identity
page=course-02-find-every-grant-for-an-identity.md
cluster_columns="$(page_run "$page" 'kubectl get clusterrolebindings -o custom-columns=NAME:.metadata.name,ROLE:.roleRef.name,KIND:.subjects[*].kind,SUBJECT:.subjects[*].name')"
expect 'the ClusterRoleBinding list has the columns NAME ROLE KIND SUBJECT' "$(head -n 1 <<<"$cluster_columns" | tr -s ' ')" 'NAME ROLE KIND SUBJECT'
expect 'the list has built-in system: bindings' "$cluster_columns" 'system:'
namespaced_columns="$(page_run "$page" 'kubectl get rolebindings --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,ROLEKIND:.roleRef.kind,ROLE:.roleRef.name,KIND:.subjects[*].kind,SUBJECT:.subjects[*].name')"
printf '%s\n' "$namespaced_columns"
expect 'the RoleBinding list has RoleBindings in kube-system' "$namespaced_columns" kube-system
expect 'the RoleBinding list has RoleBindings in kube-public' "$namespaced_columns" kube-public
expect 'shuttle-configmap-reader is in outpost' "$(grep -E '^outpost[[:space:]]+shuttle-configmap-reader[[:space:]]' <<<"$namespaced_columns" || true)" shuttle
expect 'crew-view gives view to the group starfleet-crew' "$(grep -E '^outpost[[:space:]]+crew-view[[:space:]]' <<<"$namespaced_columns" | tr -s ' ' || true)" 'ClusterRole view Group starfleet-crew'
scout_row="$(page_run "$page" 'kubectl get clusterrolebindings -o custom-columns=NAME:.metadata.name,ROLE:.roleRef.name,KIND:.subjects[*].kind,SUBJECT:.subjects[*].name | grep scout')"
printf '%s\n' "$scout_row"
expect 'grep finds scout-edit-everywhere with the role edit' "$(tr -s ' ' <<<"$scout_row")" 'scout-edit-everywhere edit'
scout_wide="$(page_run "$page" 'kubectl get clusterrolebindings -o wide | grep starfleet/scout')"
printf '%s\n' "$scout_wide"
expect 'the wide grep finds scout-edit-everywhere with the role edit' "$(tr -s ' ' <<<"$scout_wide")" 'scout-edit-everywhere ClusterRole/edit'
broad_groups="$(page_run "$page" "kubectl get clusterrolebindings,rolebindings --all-namespaces -o wide | grep -E 'system:authenticated|system:unauthenticated|system:serviceaccounts'")"
printf '%s\n' "$broad_groups"
expect 'the broad-group search finds the built-in binding system:discovery' "$broad_groups" system:discovery
expect 'the broad-group search finds the built-in binding system:basic-user' "$broad_groups" system:basic-user
expect_no 'the broad-group search does not list the scout binding' "$broad_groups" scout-edit-everywhere
role_rules="$(page_run "$page" 'kubectl -n outpost describe role configmap-reader')"
printf '%s\n' "$role_rules"
expect 'configmap-reader has one rule for configmaps with get and list' "$(rule_rows "$role_rules" configmaps)" '[get list]'
scout_rules="$(page_run "$page" "kubectl auth can-i --list -n outpost $scout")"
expect 'the rules of scout have a row for secrets' "$(rule_rows "$scout_rules" secrets)" secrets
expect 'the rules of scout have a row for pods/exec' "$(rule_rows "$scout_rules" pods/exec)" create
expect 'the rules of scout have write verbs for configmaps' "$(rule_rows "$scout_rules" configmaps)" update

# Rewrite a broad grant as least privilege
page=course-03-rewrite-a-broad-grant-as-least-privilege.md
expect_can_i "$page" "kubectl auth can-i list services -n outpost $crew" yes 'view lets the crew list Services'
expect_can_i "$page" "kubectl auth can-i get pods/log -n outpost $crew" yes 'view lets the crew read Pod logs'
save_from_page "$page" role-crew-pod-reader.yaml
page_run "$page" 'kubectl -n outpost delete rolebinding crew-view'
expect_can_i "$page" "kubectl auth can-i list pods -n outpost $crew" yes 'the narrow Role lets the crew list Pods'
expect_can_i "$page" "kubectl auth can-i get pods/log -n outpost $crew" yes 'the narrow Role lets the crew read Pod logs'
expect_can_i "$page" "kubectl auth can-i list services -n outpost $crew" no 'Services are gone from the grant'
expect_can_i "$page" "kubectl auth can-i list pods -n starfleet $crew" no 'the grant does not reach starfleet'
expect 'the built-in ClusterRole view stays' "$(kubectl get clusterrole view -o name)" clusterrole.rbac.authorization.k8s.io/view

# Playground guide
page=playground/docs/overview.md
# `export KUBECONFIG="$(astrona kubeconfig ...)"` is left out: the CI script
# already sets KUBECONFIG to this playground's file. The context check runs.
page_run "$page" 'test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-010-02" || exit 1'
expect_equal 'the guide context check passes' "$(kubectl config current-context)" kind-astro-ats-032-playground-010-02

stop_after_failed_lookup
printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
