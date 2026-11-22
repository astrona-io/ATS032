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
cluster_name=astro-ats-032-playground-020-03
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


# Find which pods use which ServiceAccount
page=course-01-find-which-pods-use-which-serviceaccount.md
all_pods="$(page_run "$page" 'kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,SERVICEACCOUNT:.spec.serviceAccountName,AUTOMOUNT:.spec.automountServiceAccountToken')"
expect_equal 'CoreDNS pods use their own coredns account' "$(awk '$1 == "kube-system" && $2 ~ /^coredns-/ {print $3}' <<<"$all_pods" | sort -u)" coredns
expect 'the AUTOMOUNT column shows <none> for pods that do not set it' "$(awk '$1 == "starfleet" && $2 == "shuttle" {print $4}' <<<"$all_pods")" '<none>'
outpost_pods="$(page_run "$page" 'kubectl get pods -n outpost -o custom-columns=NAME:.metadata.name,SERVICEACCOUNT:.spec.serviceAccountName,AUTOMOUNT:.spec.automountServiceAccountToken')"
printf '%s\n' "$outpost_pods"
expect_equal 'ledger-client shows false' "$(awk '$1 == "ledger-client" {print $3}' <<<"$outpost_pods")" false
expect_equal 'archive-reader shows <none>' "$(awk '$1 == "archive-reader" {print $3}' <<<"$outpost_pods")" '<none>'
accounts="$(page_run "$page" 'kubectl get serviceaccounts -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,AUTOMOUNT:.automountServiceAccountToken')"
printf '%s\n' "$accounts" | grep -E '^outpost ' || true
expect_equal 'the archive account shows false' "$(awk '$1 == "outpost" && $2 == "archive" {print $3}' <<<"$accounts")" false
expect_equal 'the ledger account shows <none>' "$(awk '$1 == "outpost" && $2 == "ledger" {print $3}' <<<"$accounts")" '<none>'
expect_equal 'every default account shows <none>' "$(awk '$2 == "default" {print $3}' <<<"$accounts" | sort -u)" '<none>'
token_listing="$(page_run "$page" 'kubectl -n outpost exec drifter -- ls /var/run/secrets/kubernetes.io/serviceaccount')"
printf '%s\n' "$token_listing"
expect 'drifter has ca.crt' "$token_listing" ca.crt
expect 'drifter has namespace' "$token_listing" namespace
expect 'drifter has token' "$token_listing" token
token_listing="$(page_fails "$page" 'kubectl -n outpost exec archive-reader -- ls /var/run/secrets/kubernetes.io/serviceaccount')"
printf '%s\n' "$token_listing"
expect 'ls in archive-reader fails because the directory does not exist' "$token_listing" 'No such file or directory'
projected="$(page_run "$page" "kubectl -n outpost get pod ledger-client -o jsonpath='{.spec.volumes[*].projected}{\"\n\"}'")"
printf '%s\n' "$projected"
expect 'ledger-client has one serviceAccountToken source' "$projected" serviceAccountToken
expect 'the token path is token' "$projected" '"path":"token"'
expect 'the token lives 86400 seconds' "$projected" '"expirationSeconds":86400'

# Audit grants that reach ServiceAccounts
page=course-02-audit-grants-that-reach-serviceaccounts.md
outpost_bindings="$(page_run "$page" 'kubectl -n outpost get rolebindings -o wide')"
printf '%s\n' "$outpost_bindings"
expect 'outpost-all-view gives the view ClusterRole' "$(grep '^outpost-all-view ' <<<"$outpost_bindings")" ClusterRole/view
expect 'outpost-all-view names the group of outpost accounts' "$(grep '^outpost-all-view ' <<<"$outpost_bindings")" system:serviceaccounts:outpost
cluster_bindings="$(page_run "$page" 'kubectl get clusterrolebindings -o wide')"
grep '^ledger-edit ' <<<"$cluster_bindings" || true
expect 'ledger-edit gives the edit ClusterRole' "$(grep '^ledger-edit ' <<<"$cluster_bindings")" ClusterRole/edit
expect 'ledger-edit names outpost/ledger' "$(grep '^ledger-edit ' <<<"$cluster_bindings")" outpost/ledger
filtered="$(page_run "$page" "kubectl get clusterrolebindings -o custom-columns=NAME:.metadata.name,ROLE:.roleRef.name,KIND:.subjects[*].kind,SUBJECT:.subjects[*].name | grep -E 'ServiceAccount|system:serviceaccounts'")"
printf '%s\n' "$filtered"
expect 'the filtered list has ledger-edit' "$filtered" ledger-edit
expect 'the filtered list has system bindings too' "$filtered" 'system:'
expect_equal 'ledger may get Secrets in outpost' "$(page_run "$page" 'kubectl auth can-i get secrets -n outpost --as=system:serviceaccount:outpost:ledger')" yes
expect_equal 'archive may list pods in outpost through the group binding' "$(page_run "$page" 'kubectl auth can-i list pods -n outpost --as=system:serviceaccount:outpost:archive')" yes
archive_rules="$(page_run "$page" 'kubectl auth can-i --list -n outpost --as=system:serviceaccount:outpost:archive')"
expect 'the rule list of archive has the view rules for pods' "$(grep -E '^pods ' <<<"$archive_rules")" '[get list watch]'

# Audit tokens: Secrets, lifetimes and audience
page=course-03-audit-tokens-secrets-lifetimes-and-audience.md
# The page adds and removes a kubeconfig user. Work on a copy of the kubeconfig,
# so the playground file that CI handed over stays as it was.
kubectl config view --raw >"$work_directory/kubeconfig"
export KUBECONFIG="$work_directory/kubeconfig"
token_secrets="$(page_run "$page" 'kubectl get secrets -A --field-selector type=kubernetes.io/service-account-token')"
printf '%s\n' "$token_secrets"
expect_equal 'the cluster has one service account token Secret' "$(awk 'NR > 1' <<<"$token_secrets" | wc -l | tr -d ' ')" 1
expect 'the Secret is ledger-legacy-token in outpost' "$(awk 'NR > 1 {print $1 "/" $2}' <<<"$token_secrets")" outpost/ledger-legacy-token
secret_accounts="$(page_run "$page" "kubectl get secrets -A --field-selector type=kubernetes.io/service-account-token -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,SERVICEACCOUNT:'.metadata.annotations.kubernetes\\.io/service-account\\.name'")"
printf '%s\n' "$secret_accounts"
expect_equal 'the Secret belongs to ledger' "$(awk '$2 == "ledger-legacy-token" {print $3}' <<<"$secret_accounts")" ledger
page_run "$page" 'kubectl -n outpost delete secret ledger-legacy-token'
lifetimes="$(page_run "$page" "kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{\"/\"}{.metadata.name}{\"\\t\"}{.spec.volumes[*].projected.sources[*].serviceAccountToken.expirationSeconds}{\"\\n\"}{end}'")"
grep -E '^(outpost|starfleet)/' <<<"$lifetimes" || true
expect_equal 'a pod with the default mount shows 3607' "$(awk -F '\t' '$1 == "outpost/drifter" {print $2}' <<<"$lifetimes")" "$(text_from_page "$page" 3607)"
expect_equal 'outpost/ledger-client shows 86400' "$(awk -F '\t' '$1 == "outpost/ledger-client" {print $2}' <<<"$lifetimes")" "$(text_from_page "$page" 86400)"
page_run "$page" 'kubectl config set-credentials archive-token --token="$(kubectl -n outpost create token archive)"'
identity="$(page_run "$page" 'kubectl --user=archive-token auth whoami')"
printf '%s\n' "$identity"
expect 'whoami prints the archive account' "$identity" "$(text_from_page "$page" system:serviceaccount:outpost:archive)"
expect 'whoami prints the groups of the account' "$identity" system:serviceaccounts:outpost
page_run "$page" 'kubectl config set-credentials archive-token --token="$(kubectl -n outpost create token archive --audience=ledger)"'
refused="$(page_fails "$page" 'kubectl --user=archive-token auth whoami')"
printf '%s\n' "$refused"
expect 'a token for the audience ledger is Unauthorized at the API server' "$refused" Unauthorized
page_run "$page" 'kubectl config set-credentials archive-token --token="$(kubectl -n outpost create token archive --duration=10m)"'
expect_equal 'a ten-minute token may list pods in outpost' "$(page_run "$page" 'kubectl --user=archive-token auth can-i list pods -n outpost')" yes
page_run "$page" 'kubectl config delete-user archive-token'
expect_no 'the user archive-token is gone from the kubeconfig' "$(kubectl config view -o jsonpath='{.users[*].name}')" archive-token

# Playground guide
page=playground/docs/overview.md
# The guide first points KUBECONFIG at the playground with `astrona kubeconfig`.
# scripts/ci/test-playground.sh has already done that, so the export is left out.
page_run "$page" 'test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-020-03" || exit 1'
expect_equal 'the probe Deployment has two ready replicas' "$(kubectl -n starfleet get deployment probe -o jsonpath='{.status.readyReplicas}')" 2
expect 'the ServiceAccounts ledger and archive exist' "$(kubectl -n outpost get serviceaccount ledger archive -o name)" serviceaccount/archive
expect 'the ClusterRoleBinding ledger-edit exists' "$(kubectl get clusterrolebinding ledger-edit -o name)" ledger-edit
expect 'the RoleBinding outpost-all-view exists' "$(kubectl -n outpost get rolebinding outpost-all-view -o name)" outpost-all-view

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
