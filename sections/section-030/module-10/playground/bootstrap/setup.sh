#!/usr/bin/env bash
# Bootstrap for playground ats-032-playground-030-01. astrona pipes this script
# into bash on the VM as the astrona account (passwordless sudo), with no other
# file next to it, so the start objects are inlined below.
#
# The image (ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks-*) already has
# containerd, kubeadm/kubelet/kubectl v1.35 and the python:3.13-alpine and
# busybox:1.37.0 images, so the playground needs no network.

PLAYGROUND=ats-032-playground-030-01
NODE=controlplane

kube() {
  sudo -n kubectl --kubeconfig /etc/kubernetes/admin.conf "$@"
}

main() {
  set -euo pipefail

  # Context guard: run only on a VM built from the kubeadm image.
  if [ ! -x /usr/local/sbin/astrona-kubeadm-init ]; then
    echo "Refusing to run: this VM is not built from the CKS practice image" >&2
    exit 1
  fi

  local users=()
  id student >/dev/null 2>&1 && users+=(--user student)
  sudo -n /usr/local/sbin/astrona-kubeadm-init \
    --node-name "$NODE" --cluster-name "astro-$PLAYGROUND" "${users[@]}" </dev/null

  local context
  context=$(kube config current-context </dev/null)
  if [ "$context" != "kubernetes-admin@astro-$PLAYGROUND" ]; then
    echo "Refusing to continue on context $context" >&2
    exit 1
  fi

  kube apply -f - <<'MANIFEST'
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
  server.py: "from http.server import BaseHTTPRequestHandler, HTTPServer\nfrom pathlib\
    \ import Path\nimport os\nimport socket\n\nclass Handler(BaseHTTPRequestHandler):\n\
    \    def do_GET(self):\n        marker = {\"/ready\": \"/tmp/not-ready\", \"/health\"\
    : \"/tmp/unhealthy\"}.get(self.path)\n        status = 503 if marker and Path(marker).exists()\
    \ else 200\n        settings = Path(\"/settings/greeting\")\n        greeting\
    \ = settings.read_text().strip() if settings.exists() else os.getenv(\"GREETING\"\
    , \"hello\")\n        body = f\"version={os.getenv('VERSION', 'v1')} host={socket.gethostname()}\
    \ greeting={greeting}\\n\"\n        self.send_response(status)\n        self.send_header(\"\
    Content-Type\", \"text/plain\")\n        self.end_headers()\n        self.wfile.write(body.encode())\n\
    \nHTTPServer((\"0.0.0.0\", 8080), Handler).serve_forever()\n"
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
MANIFEST
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
