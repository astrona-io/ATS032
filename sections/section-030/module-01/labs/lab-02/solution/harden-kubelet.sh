#!/usr/bin/env bash
# Runs inside the worker node container: anonymous requests off, Webhook
# authorization, read-only port off, then restart the kubelet.
set -euo pipefail
file=/var/lib/kubelet/config.yaml
sed -i \
  -e '/^  anonymous:$/{n;s/enabled: true/enabled: false/}' \
  -e 's/^  mode: AlwaysAllow$/  mode: Webhook/' \
  -e 's/^readOnlyPort: .*/readOnlyPort: 0/' \
  "$file"
systemctl restart kubelet
