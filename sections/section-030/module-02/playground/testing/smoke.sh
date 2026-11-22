#!/usr/bin/env bash
# Runs the commands that the module pages and the playground guide teach
# inside the playground VM and fails when one of them does not give the result
# the page describes. Every command is first looked up on its page and then run
# exactly as the page writes it, and every YAML file comes from the page.
# scripts/ci/test-playground.sh copies the pages and this folder into the VM
# and runs the script there as the student user. The VM is the only node,
# controlplane, so node commands use sudo directly. No page step changes the
# API server manifest, so nothing here restarts a component.
set -euo pipefail
# Keep set -e inside $(...), so a failed page lookup also stops a captured command.
shopt -s inherit_errexit 2>/dev/null || true
cluster_name=astro-ats-032-playground-030-02
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

# The call_api helper as the pages define it, with the `bad` mode. The text is
# the same on the first two pages, and each page's copy is looked up there.
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
elif mode == 'bad':
    req.add_header('Authorization', 'Bearer not-a-real-token')
try:
    print(urllib.request.urlopen(req, context=ctx, timeout=5).status)
except urllib.error.HTTPError as e:
    print(e.code)
PY
}
CMD
)"

# Playground guide. It runs first: it describes the starting state, and the
# second page deletes the ClusterRoleBinding anonymous-viewer. The guide's
# only command, `astrona ssh astro-ats-032-playground-030-02`, is left out: it
# runs on the learner's machine, and this script already runs in that shell.
# The checks below use plain kubectl reads for the facts the guide states.
page=playground/docs/overview.md
text_from_page "$page" "astrona ssh $cluster_name" >/dev/null
nodes="$(kubectl get nodes)"
expect_equal 'the cluster has one node' "$(grep -vc '^NAME' <<<"$nodes" || true)" 1
expect 'the only node is controlplane and it is Ready' "$(grep -E '^controlplane ' <<<"$nodes" || true)" Ready
expect 'kubectl runs as kubernetes-admin' "$(kubectl auth whoami -o jsonpath='{.status.userInfo.username}')" kubernetes-admin
expect_equal 'probe has two ready replicas' "$(kubectl -n starfleet get deployment probe -o jsonpath='{.status.readyReplicas}')" 2
expect_equal 'starfleet has the Service probe' "$(kubectl -n starfleet get service probe -o jsonpath='{.metadata.name}')" probe
expect_equal 'shuttle runs in starfleet' "$(kubectl -n starfleet get pod shuttle -o jsonpath='{.status.phase}')" Running
expect_equal 'drifter runs in outpost' "$(kubectl -n outpost get pod drifter -o jsonpath='{.status.phase}')" Running
expect_equal 'every example Pod uses the default ServiceAccount' "$(kubectl get pods -n starfleet -o jsonpath='{.items[*].spec.serviceAccountName}' | tr ' ' '\n' | sort -u) $(kubectl get pods -n outpost -o jsonpath='{.items[*].spec.serviceAccountName}')" 'default default'
expect_equal 'anonymous-viewer gives view to system:unauthenticated' "$(kubectl get clusterrolebinding anonymous-viewer -o jsonpath='{.roleRef.name} {.subjects[*].kind} {.subjects[*].name}')" 'view Group system:unauthenticated'
expect_equal 'ops-viewer gives view to the group ops' "$(kubectl get clusterrolebinding ops-viewer -o jsonpath='{.roleRef.name} {.subjects[*].kind} {.subjects[*].name}')" 'view Group ops'
expect 'the API server manifest is on the node' "$(sudo ls /etc/kubernetes/manifests)" kube-apiserver.yaml

# Authentication methods and identities
page=course-01-authentication-methods-and-identities.md
whoami="$(page_run "$page" 'kubectl auth whoami')"
printf '%s\n' "$whoami"
expect 'whoami shows the user kubernetes-admin' "$(tr -s ' ' <<<"$whoami")" 'Username kubernetes-admin'
expect 'whoami shows the two groups' "$(tr -s ' ' <<<"$whoami")" 'Groups [kubeadm:cluster-admins system:authenticated]'
expect 'whoami shows the certificate ID' "$(tr -s ' ' <<<"$whoami")" 'Extra: authentication.kubernetes.io/credential-id [X509SHA256='
impersonated="$(page_run "$page" 'kubectl auth whoami --as=system:serviceaccount:starfleet:default')"
expect_equal 'whoami as the ServiceAccount shows its name and three groups' "$(tr -s ' ' <<<"$impersonated")" "$(output_from_page "$page" 'kubectl auth whoami --as=' | tr -s ' ')"
token_command="$(cat <<'CMD'
kubectl -n starfleet create token default | python3 -c "import sys,base64,json;p=sys.stdin.read().split('.')[1];print(json.dumps(json.loads(base64.urlsafe_b64decode(p+'='*(-len(p)%4))),indent=2))"
CMD
)"
claims="$(page_run "$page" "$token_command")"
printf '%s\n' "$claims"
# Only the fields that the page says do not change are compared.
claim() {
  python3 -c 'import json, sys; print(json.dumps(eval("c" + sys.argv[1], {"c": json.load(sys.stdin)})))' "$1" <<<"$claims"
}
page_claims="$(output_from_page "$page" 'kubectl -n starfleet create token default')"
page_claim() {
  python3 -c 'import json, sys; print(json.dumps(eval("c" + sys.argv[1], {"c": json.load(sys.stdin)})))' "$1" <<<"$page_claims"
}
for claim_path in '["aud"]' '["iss"]' '["sub"]' '["kubernetes.io"]["namespace"]' '["kubernetes.io"]["serviceaccount"]["name"]'; do
  expect_equal "the token claim $claim_path is the one the page shows" "$(claim "$claim_path")" "$(page_claim "$claim_path")"
done
expect_equal 'the token claim sub names the default ServiceAccount' "$(claim '["sub"]')" '"system:serviceaccount:starfleet:default"'
expect_equal 'exp is 3600 seconds after iat' "$(python3 -c 'import json, sys; c = json.load(sys.stdin); print(c["exp"] - c["iat"])' <<<"$claims")" "$(text_from_page "$page" 3600)"
page_run "$page" "$call_api_definition"
expect_equal '/version without a credential gives 200' "$(page_run "$page" 'call_api /version anon')" 200
expect_equal '/version with the mounted token gives 200' "$(page_run "$page" 'call_api /version token')" 200
expect_equal '/version with a token that is not valid gives 401' "$(page_run "$page" 'call_api /version bad')" 401

# Anonymous access in practice
page=course-02-anonymous-access-in-practice.md
page_run "$page" "$call_api_definition"
expect_equal '/version without a credential gives 200' "$(page_run "$page" 'call_api /version anon')" 200
expect_equal 'listing Pods without a credential gives 200 at the start' "$(page_run "$page" 'call_api /api/v1/namespaces/starfleet/pods anon')" 200
save_yaml_from_page "$page" subjectaccessreview-anonymous-pods.yaml
review_command="$(cat <<'CMD'
kubectl create -f subjectaccessreview-anonymous-pods.yaml -o jsonpath='{.status}{"\n"}'
CMD
)"
expect_equal 'the review allows anonymous listing and names anonymous-viewer' "$(page_run "$page" "$review_command")" "$(output_from_page "$page" 'kubectl create -f subjectaccessreview-anonymous-pods.yaml')"
# The page says this can-i fails for the anonymous caller.
can_i_anonymous="$(kubectl auth can-i list pods -n starfleet --as=system:anonymous --as-group=system:unauthenticated 2>&1 || true)"
text_from_page "$page" 'kubectl auth can-i list pods -n starfleet --as=system:anonymous --as-group=system:unauthenticated' >/dev/null
expect 'can-i as the anonymous caller is refused' "$can_i_anonymous" "$(text_from_page "$page" 'User "system:anonymous" cannot create resource "selfsubjectaccessreviews"')"
cluster_bindings_command="$(cat <<'CMD'
kubectl get clusterrolebindings -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.roleRef.name}{"\t"}{.subjects[*].name}{"\n"}{end}'
CMD
)"
cluster_bindings="$(page_run "$page" "$cluster_bindings_command")"
expect_equal 'the ClusterRoleBinding list has more than 50 lines' "$(( $(grep -c . <<<"$cluster_bindings" || true) > 50 ))" 1
page_bindings="$(output_from_page "$page" 'kubectl get clusterrolebindings -o jsonpath=')"
while IFS= read -r binding_line; do
  expect "the ClusterRoleBinding list has: ${binding_line%%$'\t'*}" $'\n'"$cluster_bindings"$'\n' $'\n'"$binding_line"$'\n'
done <<<"$page_bindings"
role_bindings_command="$(cat <<'CMD'
kubectl get rolebindings -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.roleRef.name}{"\t"}{.subjects[*].name}{"\n"}{end}'
CMD
)"
role_bindings="$(page_run "$page" "$role_bindings_command")"
printf '%s\n' "$role_bindings"
expect_equal 'the RoleBinding list has eleven lines' "$(grep -c . <<<"$role_bindings" || true)" 11
expect_equal 'only the bootstrap RoleBinding names an anonymous subject' "$(grep -E 'system:(anonymous|unauthenticated)' <<<"$role_bindings" || true)" "$(output_from_page "$page" 'kubectl get rolebindings -A -o jsonpath=')"
page_run "$page" 'kubectl delete clusterrolebinding anonymous-viewer'
expect_equal '/version without a credential still gives 200' "$(page_run "$page" 'call_api /version anon')" 200
# The page says to repeat the request after a few seconds if it still shows 200.
anonymous_pods="$(wait_for_output 403 page_run "$page" 'call_api /api/v1/namespaces/starfleet/pods anon')"
expect_equal 'listing Pods without a credential now gives 403' "$(tail -1 <<<"$anonymous_pods")" 403
expect_equal 'the review now says allowed false' "$(page_run "$page" "$review_command")" "$(text_from_page "$page" '{"allowed":false}')"

# Authorization modes and impersonation
page=course-03-authorization-modes-and-impersonation.md
mode_command="$(cat <<'CMD'
kubectl -n kube-system get pod -l component=kube-apiserver -o jsonpath='{range .items[0].spec.containers[0].command[*]}{@}{"\n"}{end}' | grep -e authorization -e anonymous
CMD
)"
expect_equal 'the live flag list has only the authorization mode' "$(page_run "$page" "$mode_command")" "$(output_from_page "$page" 'grep -e authorization -e anonymous')"
expect_equal 'the manifest holds the same flag as a list item' "$(page_run "$page" 'sudo grep -e authorization -e anonymous /etc/kubernetes/manifests/kube-apiserver.yaml')" "$(output_from_page "$page" 'sudo grep -e authorization')"
expect_equal 'the default ServiceAccount may not list Pods' "$(page_fails "$page" 'kubectl auth can-i list pods -n starfleet --as=system:serviceaccount:starfleet:default')" no
expect_equal 'the group ops may list Pods' "$(page_run "$page" 'kubectl auth can-i list pods -n starfleet --as=ops-user --as-group=ops')" yes
forbidden="$(page_fails "$page" 'kubectl get pods -n starfleet --as=system:serviceaccount:starfleet:default')"
expect_equal 'get pods as the ServiceAccount is Forbidden' "$forbidden" "$(output_from_page "$page" 'kubectl get pods -n starfleet --as=' | head -1)"
expect_equal 'the administrator may impersonate ServiceAccounts' "$(page_run "$page" 'kubectl auth can-i impersonate serviceaccounts')" yes

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
