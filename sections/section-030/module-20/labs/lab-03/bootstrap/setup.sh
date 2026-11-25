#!/usr/bin/env bash
# Bootstrap for lab ats-032-lab-030-02-03. vm/install.sh builds the one-node
# cluster (node controlplane) and runs this script inside the lab VM from
# /opt/astrona-lab as the VM administrator user (passwordless sudo).
#
# It gives the group helpdesk a broad impersonation grant and appends
# AlwaysAllow to the authorization modes of the kube-apiserver static Pod.
#
# With AlwaysAllow the API server turns anonymous authentication off (its log
# says "AnonymousAuth is not allowed with the AlwaysAllow authorizer. Resetting
# AnonymousAuth to false"). The kubelet's probes of the API server are
# anonymous HTTPS requests, so they get 401, the Pod never becomes Ready and
# the startup probe restarts it. The bootstrap therefore changes the three
# probes to TCP checks on the same port.

LAB_NAME=ats-032-lab-030-02-03
NODE=controlplane
MANIFEST=/etc/kubernetes/manifests/kube-apiserver.yaml

kube() {
  sudo -n kubectl --kubeconfig /etc/kubernetes/admin.conf --request-timeout=10s "$@"
}

seed_objects() {
  kube apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: starfleet-032-030-02-03
---
apiVersion: v1
kind: Namespace
metadata:
  name: outpost-032-030-02-03
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: probe
  namespace: starfleet-032-030-02-03
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: probe
  namespace: outpost-032-030-02-03
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: helpdesk-impersonate
rules:
- apiGroups: [""]
  resources: ["users", "groups", "serviceaccounts"]
  verbs: ["impersonate"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: helpdesk-impersonate
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: helpdesk-impersonate
subjects:
- kind: Group
  name: helpdesk
  apiGroup: rbac.authorization.k8s.io
EOF
}

main() {
  set -euo pipefail

  # Context guard: run only against this VM's own cluster.
  local context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-$LAB_NAME}"
  if [ "$(kubectl config current-context)" != "$context" ]; then
    echo "Refusing to operate on another Kubernetes context" >&2
    exit 1
  fi

  seed_objects </dev/null

  if ! sudo -n grep -q -- '--authorization-mode=.*AlwaysAllow' "$MANIFEST"; then
    sudo -n sed -i \
      -e 's/^\( *- --authorization-mode=.*\)$/\1,AlwaysAllow/' \
      -e '/httpGet:/,/scheme: HTTPS/{s/httpGet:/tcpSocket:/;/path:/d;/scheme:/d}' \
      "$MANIFEST"
  fi

  local attempt answer ready
  for attempt in $(seq 1 60); do
    answer=$(kube auth can-i list secrets -n kube-system --as=nobody 2>/dev/null </dev/null) || true  # can-i exits 1 when it prints no
    ready=$(kube get --raw /readyz 2>/dev/null </dev/null) || ready=""
    if [ "$answer" = yes ] && [ "$ready" = ok ]; then
      echo "The API server runs with AlwaysAllow (attempt $attempt)"
      break
    fi
    if [ "$attempt" = 60 ]; then
      echo "The API server did not come back with AlwaysAllow within five minutes" >&2
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
