---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Summary

This module followed a request to the Kubernetes API from the client to the datastore, and then narrowed what it can reach.

- Every request is authenticated, authorized and admitted, in that order. A `401` means the credential was not accepted, a `403` means the identity is known and not allowed, and admission rejects the content of a write.
- Anonymous requests become `system:anonymous` when `--anonymous-auth` is `true`. A kubeadm cluster lets them read only health and version paths. Never bind a broad role to `system:anonymous` or `system:unauthenticated`.
- A workload gets its own ServiceAccount, a Role with the exact resources and verbs, and a RoleBinding in its namespace. Verify it from inside the Pod, with the mounted token and CA file, and check both an allowed and a denied request.
- Set `--authorization-mode=Node,RBAC`, keep `NodeRestriction` enabled, and turn off anonymous access where nothing needs it.
- Close the kubelet API: `anonymous.enabled: false`, `authorization.mode: Webhook` and `readOnlyPort: 0`.
- Restrict network access to ports 6443, 10250, 2379 and 2380 to the hosts that need them.
- An audit policy chooses a level per rule. Use `Metadata` for Secrets, and use `RequestResponse` for RBAC changes.
- Edit the API server static Pod manifest with a backup stored outside `/etc/kubernetes/manifests`, and add a volume for every file that a new flag names.

Clean up the playground when you finish.

<!-- astrona:playground:destroy -->
