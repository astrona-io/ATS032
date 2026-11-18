#!/usr/bin/env bash
# Reference solution for lab ats-032-lab-030-02-03, run by `astrona test`.
# astrona pipes it into bash on the lab VM as the astrona account, with no
# other lab file next to it. It follows the same steps as solution.md: set the
# authorization modes back to Node,RBAC, wait for the restarted API server,
# then narrow the impersonation grant of the group helpdesk to one
# ServiceAccount in one namespace.

LAB_NAME=ats-032-lab-030-02-03
MANIFEST=/etc/kubernetes/manifests/kube-apiserver.yaml

kube() {
  sudo -n kubectl --kubeconfig /etc/kubernetes/admin.conf --request-timeout=10s "$@"
}

main() {
  set -euo pipefail

  local context
  context=$(kube config current-context </dev/null)
  if [ "$context" != "kubernetes-admin@astro-$LAB_NAME" ]; then
    echo "Refusing to operate on context $context" >&2
    exit 1
  fi

  sudo -n cp "$MANIFEST" /root/kube-apiserver.yaml.bak
  sudo -n sed -i 's/--authorization-mode=Node,RBAC,AlwaysAllow/--authorization-mode=Node,RBAC/' "$MANIFEST"
  sudo -n grep -- '--authorization-mode=' "$MANIFEST"

  local attempt answer ready
  for attempt in $(seq 1 60); do
    answer=$(kube auth can-i list secrets -n kube-system --as=nobody 2>/dev/null </dev/null) || true  # can-i exits 1 when it prints no
    ready=$(kube get --raw /readyz 2>/dev/null </dev/null) || ready=""
    if [ "$answer" = no ] && [ "$ready" = ok ]; then
      echo "The API server runs with Node,RBAC (attempt $attempt)"
      break
    fi
    if [ "$attempt" = 60 ]; then
      echo "The API server did not come back within five minutes" >&2
      exit 1
    fi
    sleep 5
  done

  kube apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: helpdesk-impersonate
rules:
- apiGroups: [""]
  resources: ["serviceaccounts"]
  resourceNames: ["probe"]
  verbs: ["impersonate"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: helpdesk-impersonate
  namespace: starfleet-032-030-02-03
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: helpdesk-impersonate
subjects:
- kind: Group
  name: helpdesk
  apiGroup: rbac.authorization.k8s.io
EOF
  kube delete clusterrolebinding helpdesk-impersonate </dev/null
}

main "$@"
