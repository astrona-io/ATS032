#!/usr/bin/env bash
# Bootstrap for the playground ats-032-playground-040-03. astrona pipes this
# script into bash on the playground VM as the astrona account (passwordless
# sudo), with no other playground file next to it.
#
# The image (ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks-*) already has
# containerd, kubeadm/kubelet/kubectl v1.35 on hold, the control-plane images
# and the example workload images in containerd. This script creates the
# single-node cluster, copies etcdctl and etcdutl out of the etcd image and
# starts the example workloads. It needs no network.

LAB_NAME=ats-032-playground-040-03
NODE=controlplane

kube() {
  sudo -n kubectl --kubeconfig /etc/kubernetes/admin.conf "$@"
}

# Copy etcdctl and etcdutl from the etcd image that the cluster already runs.
# The image has no shell, so the script exports the image from containerd as
# an OCI archive and unpacks the two files from its layers. Nothing is pulled.
install_etcd_tools() {
  local image work blob
  image=$(sudo -n sed -n 's/^ *image: *//p' /etc/kubernetes/manifests/etcd.yaml | head -n1)
  [ -n "$image" ] || { echo "no etcd image in /etc/kubernetes/manifests/etcd.yaml" >&2; return 1; }
  work=$(mktemp -d)
  sudo -n ctr -n k8s.io images export --local --platform "linux/$(dpkg --print-architecture)" \
    "$work/etcd-image.tar" "$image"
  mkdir -p "$work/image" "$work/files"
  sudo -n tar -xf "$work/etcd-image.tar" -C "$work/image"
  for blob in "$work"/image/blobs/sha256/*; do
    # Only the layers are gzip archives; the other blobs are JSON and are skipped.
    sudo -n tar -xzf "$blob" -C "$work/files" usr/local/bin/etcdctl usr/local/bin/etcdutl 2>/dev/null || true
  done
  sudo -n install -m 0755 "$work/files/usr/local/bin/etcdctl" "$work/files/usr/local/bin/etcdutl" /usr/local/bin/
  sudo -n rm -rf "$work"
  etcdctl version
  etcdutl version
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

  install_etcd_tools </dev/null

  # The example workloads. Every image is already in containerd.
  kube apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: starfleet
  labels:
    project: ckad
---
apiVersion: v1
kind: Namespace
metadata:
  name: outpost
  labels:
    project: outpost
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: probe-code
  namespace: starfleet
data:
  server.py: |
    from http.server import BaseHTTPRequestHandler, HTTPServer
    from pathlib import Path
    import os
    import socket

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            marker = {"/ready": "/tmp/not-ready", "/health": "/tmp/unhealthy"}.get(self.path)
            status = 503 if marker and Path(marker).exists() else 200
            settings = Path("/settings/greeting")
            greeting = settings.read_text().strip() if settings.exists() else os.getenv("GREETING", "hello")
            body = f"version={os.getenv('VERSION', 'v1')} host={socket.gethostname()} greeting={greeting}\n"
            self.send_response(status)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(body.encode())

    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: probe
  namespace: starfleet
spec:
  replicas: 2
  selector:
    matchLabels:
      app: probe
      release: probe
  template:
    metadata:
      labels:
        app: probe
        release: probe
    spec:
      containers:
      - name: probe
        image: docker.io/library/python:3.13-alpine
        imagePullPolicy: IfNotPresent
        command:
        - python
        - /app/server.py
        env:
        - name: VERSION
          value: v1
        ports:
        - name: http
          containerPort: 8080
        readinessProbe:
          httpGet:
            path: /ready
            port: http
          periodSeconds: 2
        resources:
          requests:
            cpu: 10m
            memory: 32Mi
          limits:
            memory: 128Mi
        volumeMounts:
        - name: app
          mountPath: /app
          readOnly: true
      volumes:
      - name: app
        configMap:
          name: probe-code
---
apiVersion: v1
kind: Service
metadata:
  name: probe
  namespace: starfleet
spec:
  selector:
    app: probe
    release: probe
  ports:
  - name: http
    port: 80
    targetPort: http
---
apiVersion: v1
kind: Pod
metadata:
  name: shuttle
  namespace: starfleet
  labels:
    app: shuttle
spec:
  containers:
  - name: client
    image: docker.io/library/busybox:1.37.0
    imagePullPolicy: IfNotPresent
    command:
    - sh
    - -c
    - sleep 3600
  restartPolicy: Never
---
apiVersion: v1
kind: Pod
metadata:
  name: drifter
  namespace: outpost
  labels:
    app: drifter
spec:
  containers:
  - name: client
    image: docker.io/library/busybox:1.37.0
    imagePullPolicy: IfNotPresent
    command:
    - sh
    - -c
    - sleep 3600
  restartPolicy: Never
EOF
  kube -n starfleet rollout status deployment/probe --timeout=180s </dev/null
  kube -n starfleet wait --for=condition=Ready pod/shuttle --timeout=120s </dev/null
  kube -n outpost wait --for=condition=Ready pod/drifter --timeout=120s </dev/null

  # Leave the student a shell that knows the cluster.
  if id student >/dev/null 2>&1; then
    echo 'source <(kubectl completion bash)' | sudo -n tee /etc/profile.d/kubectl-completion.sh >/dev/null
  fi

  kube get nodes -o wide </dev/null
}

main "$@"
