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
cluster_name=astro-ats-032-playground-030-03
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


# A new admission policy, binding or webhook configuration reaches the
# admission plugins of the API server after a short time. Run a page command
# that the page says must fail until it fails, at most about a minute. While
# the new rule is not active yet, the command may succeed; then the undo
# command removes what it created before the next attempt.
page_fails_once_active() {
  local page="$1" page_command="$2" undo_command="$3" output attempt
  on_page "$page" "$page_command" || exit 1
  printf '$ %s\n' "$page_command" >&2
  for attempt in $(seq 1 20); do
    if ! output="$(eval "$page_command" 2>&1)"; then
      printf '%s\n' "$output"
      return 0
    fi
    eval "$undo_command" >/dev/null 2>&1 || true
    sleep 3
  done
  printf 'FAIL: the command kept succeeding, the page says it fails: %s\n%s\n' "$page_command" "$output" >&2
  exit 1
}

# Run a page command that the page says succeeds until it succeeds, at most
# about a minute, for the same reason.
page_run_once_active() {
  local page="$1" page_command="$2" output attempt
  on_page "$page" "$page_command" || exit 1
  printf '$ %s\n' "$page_command" >&2
  for attempt in $(seq 1 20); do
    if output="$(eval "$page_command" 2>&1)"; then
      printf '%s\n' "$output"
      return 0
    fi
    sleep 3
  done
  printf 'FAIL: the command kept failing, the page says it succeeds: %s\n%s\n' "$page_command" "$output" >&2
  exit 1
}

# Pod Security admission
page=course-01-pod-security-admission.md
save_yaml_from_page "$page" pod-privileged.yaml
# The playground guide says no Pod Security label and no admission policy
# exists at the start, and this page relies on it.
expect_no 'outpost has no Pod Security label at the start' "$(kubectl get namespace outpost --show-labels)" pod-security
expect_equal 'no ValidatingAdmissionPolicy exists at the start' "$(kubectl get validatingadmissionpolicies -o name)" ''
expect 'the privileged Pod is created without a label' "$(page_run "$page" 'kubectl apply -f pod-privileged.yaml')" 'pod/debugger created'
page_run "$page" 'kubectl -n outpost delete pod debugger'
enforce_output="$(page_run "$page" 'kubectl label namespace outpost pod-security.kubernetes.io/enforce=baseline' 2>&1)"
printf '%s\n' "$enforce_output"
expect 'the label command confirms the label' "$enforce_output" 'namespace/outpost labeled'
expect_no 'drifter meets baseline, so there is no warning' "$enforce_output" Warning
rejected="$(page_fails "$page" 'kubectl apply -f pod-privileged.yaml')"
printf '%s\n' "$rejected"
expect 'the error says the Pod violates PodSecurity' "$rejected" 'violates PodSecurity'
expect 'the error names the level baseline' "$rejected" '"baseline'
expect 'the error names the privileged setting' "$rejected" privileged
save_yaml_from_page "$page" pod-plain.yaml
page_run "$page" 'kubectl label namespace outpost pod-security.kubernetes.io/warn=restricted'
plain_output="$(page_run "$page" 'kubectl apply -f pod-plain.yaml' 2>&1)"
printf '%s\n' "$plain_output"
expect 'the plain Pod is created' "$plain_output" 'pod/plain created'
expect 'a warning names the restricted level' "$plain_output" 'would violate PodSecurity "restricted'
expect 'the warning asks to forbid privilege escalation' "$plain_output" allowPrivilegeEscalation

# ValidatingAdmissionPolicy with CEL
page=course-02-validatingadmissionpolicy-with-cel.md
save_from_page "$page" vap-no-nodeport.yaml
expect 'without a binding the NodePort Service is created' "$(page_run "$page" 'kubectl -n outpost create service nodeport demo --tcp=80:80')" 'service/demo created'
# The page gives the delete command in a sentence, not in a command block.
text_from_page "$page" 'Remove it with `kubectl -n outpost delete service demo`' >/dev/null
kubectl -n outpost delete service demo
save_from_page "$page" vapb-no-nodeport-outpost.yaml
# The page says the binding becomes active after a short time and to repeat
# the request, so retry it and delete the Service an early attempt created.
denied="$(page_fails_once_active "$page" 'kubectl -n outpost create service nodeport demo --tcp=80:80' 'kubectl -n outpost delete service demo')"
printf '%s\n' "$denied"
expect 'the denial names the policy no-nodeport' "$denied" "'no-nodeport'"
expect 'the denial names the binding no-nodeport-outpost' "$denied" no-nodeport-outpost
expect 'the denial has the message of the policy' "$denied" "$(text_from_page "$page" 'NodePort Services are not allowed in this namespace')"
expect 'a ClusterIP Service in outpost is created' "$(page_run "$page" 'kubectl -n outpost create service clusterip demo --tcp=80:80')" 'service/demo created'
expect 'a NodePort Service in starfleet is created' "$(page_run "$page" 'kubectl -n starfleet create service nodeport demo --tcp=80:80')" 'service/demo created'
page_run "$page" 'kubectl -n outpost delete service demo'
page_run "$page" 'kubectl -n starfleet delete service demo'

# Admission webhooks and failure policy
page=course-03-admission-webhooks-and-failure-policy.md
save_from_page "$page" webhook-require-review.yaml
save_yaml_from_page "$page" configmap-reviewed.yaml
webhook_error="$(page_fails_once_active "$page" 'kubectl apply -f configmap-reviewed.yaml' 'kubectl -n outpost delete configmap reviewed')"
printf '%s\n' "$webhook_error"
expect 'the error names the webhook' "$webhook_error" 'failed calling webhook "require-review.outpost.example"'
expect 'the error says the Service review-service was not found' "$webhook_error" 'service "review-service" not found'
# The page states this result without a command, so create a ConfigMap
# without the label to check it.
expect 'a ConfigMap without the label is created without a call' "$(kubectl -n outpost create configmap unlabelled --from-literal=key=value)" 'configmap/unlabelled created'
kubectl -n outpost delete configmap unlabelled
page_run "$page" "kubectl patch validatingwebhookconfiguration require-review --type=json -p '[{\"op\":\"replace\",\"path\":\"/webhooks/0/failurePolicy\",\"value\":\"Ignore\"}]'"
expect_equal 'the failure policy is now Ignore' "$(kubectl get validatingwebhookconfiguration require-review -o jsonpath='{.webhooks[0].failurePolicy}')" Ignore
# The changed policy also reaches the API server after a short time.
expect 'with Ignore the ConfigMap is created' "$(page_run_once_active "$page" 'kubectl apply -f configmap-reviewed.yaml')" 'configmap/reviewed created'
page_run "$page" 'kubectl delete validatingwebhookconfiguration require-review'
page_run "$page" 'kubectl -n outpost delete configmap reviewed'

# Playground guide
page=playground/docs/overview.md
# The guide first points KUBECONFIG at the playground with `astrona kubeconfig`.
# scripts/ci/test-playground.sh has already done that, so the export is left out.
page_run "$page" 'test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-030-03" || exit 1'
expect_equal 'the probe Deployment has two ready replicas' "$(kubectl -n starfleet get deployment probe -o jsonpath='{.status.readyReplicas}')" 2
expect_equal 'the pod drifter runs in outpost' "$(kubectl -n outpost get pod drifter -o jsonpath='{.status.phase}')" Running

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
