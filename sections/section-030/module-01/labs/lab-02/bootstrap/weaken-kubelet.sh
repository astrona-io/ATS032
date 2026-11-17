#!/usr/bin/env bash
# Runs inside the worker node container. Opens the kubelet API: anonymous
# requests on, AlwaysAllow authorization and the read-only port 10255.
set -euo pipefail
file=/var/lib/kubelet/config.yaml
cp "$file" /var/lib/kubelet/config.yaml.kubeadm
awk '
  /^  anonymous:$/ { print; in_anonymous = 1; next }
  in_anonymous && /^    enabled:/ { print "    enabled: true"; in_anonymous = 0; next }
  /^  mode: Webhook$/ { print "  mode: AlwaysAllow"; next }
  /^readOnlyPort:/ { next }
  { print }
' /var/lib/kubelet/config.yaml.kubeadm > "$file"
printf 'readOnlyPort: 10255\n' >> "$file"
rm -f /var/lib/kubelet/config.yaml.kubeadm
systemctl restart kubelet
