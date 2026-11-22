#!/usr/bin/env bash
# Bootstrap for lab ats-032-lab-040-03-02. vm/install.sh builds the one-node
# cluster (node controlplane) and runs this script inside the lab VM from
# /opt/astrona-lab as the VM administrator user (passwordless sudo).
#
# Start state: the single node controlplane runs the two probe Pods and is
# cordoned for the maintenance window, but not drained. The ConfigMap
# maintenance-baseline records the containerd invocation ID and the probe Pod
# UIDs, so the graders can tell what changed. Nothing is pulled.

LAB_NAME=ats-032-lab-040-03-02
NODE=controlplane
NAMESPACE=starfleet-032-040-03-02

kube() {
  sudo -n kubectl --kubeconfig /etc/kubernetes/admin.conf "$@"
}

main() {
  set -euo pipefail

  # Context guard: run only against this VM's own cluster.
  local context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-$LAB_NAME}"
  if [ "$(kubectl config current-context)" != "$context" ]; then
    echo "Refusing to operate on another Kubernetes context" >&2
    exit 1
  fi

  kube apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: probe
  namespace: $NAMESPACE
spec:
  replicas: 2
  selector:
    matchLabels:
      app: probe
  template:
    metadata:
      labels:
        app: probe
    spec:
      containers:
      - name: probe
        image: docker.io/library/busybox:1.37.0
        imagePullPolicy: IfNotPresent
        command:
        - sh
        - -c
        - sleep 86400
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            memory: 32Mi
EOF
  kube -n "$NAMESPACE" rollout status deployment/probe --timeout=180s </dev/null

  local invocation probe_uids
  invocation=$(systemctl show containerd --property=InvocationID --value)
  probe_uids=$(kube -n "$NAMESPACE" get pods -l app=probe -o jsonpath='{.items[*].metadata.uid}' </dev/null)
  kube -n "$NAMESPACE" create configmap maintenance-baseline \
    --from-literal=containerd-invocation="$invocation" \
    --from-literal=probe-uids="$probe_uids" </dev/null

  # The maintenance window has opened: the node is cordoned, but nothing has
  # been evicted yet.
  kube cordon "$NODE" </dev/null

  # Leave the student a shell that knows the cluster.
  if id student >/dev/null 2>&1; then
    echo 'source <(kubectl completion bash)' | sudo -n tee /etc/profile.d/kubectl-completion.sh >/dev/null
  fi

  kube get nodes -o wide </dev/null
}

main "$@"
