#!/usr/bin/env bash
# Bootstrap for lab ats-032-lab-030-02-02. astrona pipes this script into
# bash on the lab VM as the astrona account (passwordless sudo).
#
# It creates the single-node kubeadm cluster, then turns on static token
# authentication: it writes a token file with one random token for a
# system:masters user, adds --token-auth-file to the kube-apiserver static Pod
# manifest and waits until the restarted API server accepts the token. The
# graders keep their own copy of the token in /var/lib/ats-032-lab.

LAB_NAME=ats-032-lab-030-02-02
NODE=controlplane
NAMESPACE=starfleet-032-030-02-02
MANIFEST=/etc/kubernetes/manifests/kube-apiserver.yaml
TOKEN_FILE=/etc/kubernetes/pki/legacy-tokens.csv

kube() {
  sudo -n kubectl --kubeconfig /etc/kubernetes/admin.conf --request-timeout=10s "$@"
}

main() {
  set -euo pipefail

  # Context guard: run only on a VM built from the kubeadm image.
  if [ ! -x /usr/local/sbin/astrona-kubeadm-init ] || [ ! -r /etc/astrona-kubeadm/versions.env ]; then
    echo "Refusing to run: this VM is not built from the CKS practice image" >&2
    exit 1
  fi

  local users=()
  id student >/dev/null 2>&1 && users+=(--user student)
  sudo -n /usr/local/sbin/astrona-kubeadm-init \
    --node-name "$NODE" --cluster-name "astro-$LAB_NAME" "${users[@]}" </dev/null

  local context
  context=$(kube config current-context </dev/null)
  if [ "$context" != "kubernetes-admin@astro-$LAB_NAME" ]; then
    echo "Refusing to continue on context $context" >&2
    exit 1
  fi

  kube create namespace "$NAMESPACE" </dev/null

  # Write the static token file and the graders' copy of the token.
  local token
  token=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
  sudo -n install -d -m 0700 /var/lib/ats-032-lab
  printf '%s' "$token" | sudo -n tee /var/lib/ats-032-lab/legacy-token >/dev/null
  printf '%s,legacy-admin,legacy-admin-uid,"system:masters"\n' "$token" | sudo -n tee "$TOKEN_FILE" >/dev/null
  sudo -n chmod 600 "$TOKEN_FILE" /var/lib/ats-032-lab/legacy-token

  # Add the flag; the kubelet restarts the API server static Pod.
  if ! sudo -n grep -q -- '--token-auth-file=' "$MANIFEST"; then
    sudo -n sed -i "/- --authorization-mode=/a\\    - --token-auth-file=$TOKEN_FILE" "$MANIFEST"
  fi

  local attempt status ready
  for attempt in $(seq 1 60); do
    status=$(curl -sk -m 5 -o /dev/null -w '%{http_code}' \
      -H "Authorization: Bearer $token" https://127.0.0.1:6443/api 2>/dev/null) || true
    ready=$(kube get --raw /readyz 2>/dev/null </dev/null) || ready=""
    if [ "$status" = 200 ] && [ "$ready" = ok ]; then
      echo "The API server accepts the static token and is ready (attempt $attempt)"
      break
    fi
    if [ "$attempt" = 60 ]; then
      echo "The API server did not come back with the static token file within five minutes" >&2
      exit 1
    fi
    sleep 5
  done
  # The kubelet replaces the mirror Pod of kube-apiserver a little after the
  # new container starts. Wait until the API shows the flag, so the graders
  # never read the old mirror Pod on the starting state.
  local command
  for attempt in $(seq 1 36); do
    command=$(kube -n kube-system get pod "kube-apiserver-$NODE" \
      -o jsonpath='{.spec.containers[0].command}' 2>/dev/null </dev/null) || command=""
    case "$command" in
      *--token-auth-file*) break ;;
    esac
    if [ "$attempt" = 36 ]; then
      echo "The mirror Pod kube-apiserver-$NODE did not show --token-auth-file within three minutes" >&2
      exit 1
    fi
    sleep 5
  done
  kube -n kube-system wait --for=condition=Ready "pod/kube-apiserver-$NODE" --timeout=180s </dev/null

  # Leave the student a shell that knows the cluster.
  if id student >/dev/null 2>&1; then
    echo 'source <(kubectl completion bash)' | sudo -n tee /etc/profile.d/kubectl-completion.sh >/dev/null
  fi

  kube get nodes -o wide </dev/null
}

main "$@"
