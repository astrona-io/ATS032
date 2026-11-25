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
cluster_name=astro-ats-032-playground-020-01
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

token_directory=/var/run/secrets/kubernetes.io/serviceaccount

# Print the lifetime in seconds (exp minus iat) of the JWT on standard input,
# without printing the token itself.
token_lifetime() {
  python3 -c '
import base64, json, sys
payload = sys.stdin.read().strip().split(".")[1]
claims = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))
print(claims["exp"] - claims["iat"])
'
}

# ServiceAccounts and the default token
page=course-010-serviceaccounts-and-the-default-token.md
expect 'starfleet has the ServiceAccount default' "$(page_run "$page" 'kubectl -n starfleet get serviceaccount')" default
expect_equal 'shuttle uses the ServiceAccount default' "$(page_run "$page" "kubectl -n starfleet get pod shuttle -o jsonpath='{.spec.serviceAccountName}{\"\n\"}'")" "$(text_from_page "$page" default)"
volume_names="$(page_run "$page" "kubectl -n starfleet get pod shuttle -o jsonpath='{.spec.volumes[*].name}{\"\n\"}'")"
printf '%s\n' "$volume_names"
expect_equal 'shuttle has one volume' "$(wc -w <<<"$volume_names" | tr -d ' ')" 1
expect 'the volume name starts with kube-api-access-' "$volume_names" "$(text_from_page "$page" kube-api-access-)"
token_files="$(page_run "$page" "kubectl -n starfleet exec shuttle -- ls $token_directory")"
expect_equal 'the mount path has ca.crt, namespace and token' "$(sort <<<"$token_files" | tr '\n' ' ')" 'ca.crt namespace token '
token_source="$(page_run "$page" "kubectl -n starfleet get pod shuttle -o jsonpath='{.spec.volumes[0].projected.sources[0].serviceAccountToken}{\"\n\"}'")"
printf '%s\n' "$token_source"
expect 'the token source has expirationSeconds 3607' "$token_source" '"expirationSeconds":3607'
expect 'the token source has the path token' "$token_source" '"path":"token"'
expect_no 'the token source has no audience field' "$token_source" audience
default_rules="$(page_run "$page" 'kubectl auth can-i --list -n starfleet --as=system:serviceaccount:starfleet:default')"
printf '%s\n' "$default_rules"
expect 'default may ask what its own permissions are' "$default_rules" selfsubjectaccessreviews.authorization.k8s.io
expect 'default may read the non-resource URL /version' "$default_rules" /version
expect_equal 'default has no rule for Pods or Secrets' "$(grep -cE '^[[:space:]]*(pods|secrets)[[:space:]]' <<<"$default_rules" || true)" 0

# Disable automounting and minimize permissions
page=course-020-disable-automounting-and-minimize-permissions.md
save_from_page "$page" serviceaccount-quiet.yaml
page_run "$page" 'kubectl -n outpost wait --for=condition=Ready pod/quiet-reader pod/quiet-override --timeout=90s'
expect 'quiet-reader has no token directory' "$(page_fails "$page" "kubectl -n outpost exec quiet-reader -- ls $token_directory")" 'No such file or directory'
expect_equal 'quiet-override lists ca.crt, namespace and token' "$(page_run "$page" "kubectl -n outpost exec quiet-override -- ls $token_directory" | sort | tr '\n' ' ')" 'ca.crt namespace token '
expect 'the default account of outpost is patched' "$(page_run "$page" "kubectl -n outpost patch serviceaccount default -p '{\"automountServiceAccountToken\": false}'")" patched
save_from_page "$page" pod-plain-check.yaml
page_run "$page" 'kubectl -n outpost wait --for=condition=Ready pod/plain-check --timeout=90s'
expect_equal 'drifter, created before the patch, still lists the three files' "$(page_run "$page" "kubectl -n outpost exec drifter -- ls $token_directory" | sort | tr '\n' ' ')" 'ca.crt namespace token '
expect 'plain-check, created after the patch, has no token directory' "$(page_fails "$page" "kubectl -n outpost exec plain-check -- ls $token_directory")" 'No such file or directory'
expect 'the ServiceAccount reporter is created' "$(page_run "$page" 'kubectl -n outpost create serviceaccount reporter')" 'reporter created'
reporter_rules="$(page_run "$page" 'kubectl auth can-i --list -n outpost --as=system:serviceaccount:outpost:reporter')"
printf '%s\n' "$reporter_rules"
expect 'reporter has the rules every authenticated identity receives' "$reporter_rules" selfsubjectaccessreviews.authorization.k8s.io
expect_equal 'reporter has no rule for Pods or Secrets' "$(grep -cE '^[[:space:]]*(pods|secrets)[[:space:]]' <<<"$reporter_rules" || true)" 0
all_role_bindings="$(page_run "$page" 'kubectl get rolebindings -A -o wide')"
printf '%s\n' "$all_role_bindings"
expect 'the binding list has a SERVICEACCOUNTS column' "$(head -n 1 <<<"$all_role_bindings")" SERVICEACCOUNTS
expect_no 'no binding names the default account of outpost' "$all_role_bindings" outpost/default
expect_no 'no binding names the default account of starfleet' "$all_role_bindings" starfleet/default

# Bound tokens, audience and legacy Secrets
page=course-030-bound-tokens-audience-and-legacy-secrets.md
page_run "$page" 'kubectl -n outpost get serviceaccount reporter || kubectl -n outpost create serviceaccount reporter'
# The token is a credential, so the test checks it without printing it.
short_token="$(page_run "$page" 'kubectl -n outpost create token reporter --duration=10m')"
expect_equal 'create token prints one JWT of three parts' "$(tr -cd '.' <<<"$short_token")" ..
lifetime="$(token_lifetime <<<"$short_token")"
printf 'token lifetime: %s seconds\n' "$lifetime"
expect_equal 'the token lives at most ten minutes' "$((lifetime > 0 && lifetime <= 600))" 1
unset short_token
save_from_page "$page" pod-ledger-client.yaml
page_run "$page" 'kubectl -n outpost wait --for=condition=Ready pod/ledger-client --timeout=90s'
expect_equal 'the projected volume holds one file, ledger-token' "$(page_run "$page" 'kubectl -n outpost exec ledger-client -- ls /var/run/tokens')" "$(text_from_page "$page" ledger-token)"
expect 'ledger-client has no default token directory' "$(kubectl -n outpost exec ledger-client -- ls "$token_directory" 2>&1 || true)" 'No such file or directory'
ledger_source="$(page_run "$page" "kubectl -n outpost get pod ledger-client -o jsonpath='{.spec.volumes[0].projected.sources[0].serviceAccountToken}{\"\n\"}'")"
printf '%s\n' "$ledger_source"
expect 'the token source has the audience ledger' "$ledger_source" '"audience":"ledger"'
expect 'the token source has expirationSeconds 600' "$ledger_source" '"expirationSeconds":600'
expect 'the token source has the path ledger-token' "$ledger_source" '"path":"ledger-token"'
save_from_page "$page" secret-reporter-legacy-token.yaml
# The token controller fills the Secret a moment after the apply (bounded wait).
wait_for_output 'token:' kubectl -n outpost describe secret reporter-legacy-token >/dev/null
legacy_secret="$(page_run "$page" 'kubectl -n outpost describe secret reporter-legacy-token')"
# The output is not printed: for this Secret type `kubectl describe` prints the
# value of the key token, not only its size.
for key in ca.crt namespace; do
  expect "the legacy Secret has the key $key, shown with its size" "$(grep -E "^$key:" <<<"$legacy_secret" || true)" bytes
done
expect_equal 'the legacy Secret has the key token' "$(grep -cE '^token:' <<<"$legacy_secret" || true)" 1
# The page says describe prints the full token value for this Secret type.
# Compare it with the stored value; print only its length, never the token.
stored_token="$(kubectl -n outpost get secret reporter-legacy-token -o jsonpath='{.data.token}' | base64 -d)"
described_token="$(sed -n 's/^token:[[:space:]]*//p' <<<"$legacy_secret")"
printf 'describe line for token: token: <%s characters>\n' "${#described_token}"
expect 'describe prints the full token value, not its size' "$([[ -n "$stored_token" && "$described_token" == "$stored_token" ]] && echo same || echo different)" same
token_secrets="$(page_run "$page" 'kubectl get secrets -A --field-selector type=kubernetes.io/service-account-token')"
printf '%s\n' "$token_secrets"
expect 'the audit lists reporter-legacy-token' "$token_secrets" reporter-legacy-token
page_run "$page" 'kubectl -n outpost delete secret reporter-legacy-token'

# Playground guide
page=playground/docs/overview.md
# `export KUBECONFIG="$(astrona kubeconfig ...)"` is left out: the CI script
# already sets KUBECONFIG to this playground's file. The context check runs.
page_run "$page" 'test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-020-01" || exit 1'
expect_equal 'the guide context check passes' "$(kubectl config current-context)" kind-astro-ats-032-playground-020-01

stop_after_failed_lookup
printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
