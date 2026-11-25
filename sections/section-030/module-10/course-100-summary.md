# Summary

Every request to the Kubernetes API passes three checks in a fixed order: authentication, authorization and admission. Authentication finds out who is calling, authorization decides whether that identity may do the action, and admission checks the content of a write. The HTTP status code shows which check said no. A `401` means the API server did not accept the credential, a `403` means the identity is known but not allowed, and an admission error names the policy that rejected the write.

When `--anonymous-auth` is `true`, which is the default, a request without a credential becomes the user `system:anonymous` in the group `system:unauthenticated`. A kubeadm cluster lets that user read only the health and version paths. The real risk is a broad role bound to `system:anonymous` or `system:unauthenticated`, because any host that can reach the API server port can then use it.

A workload that calls the API gets its own ServiceAccount, a Role with the exact resources and verbs it needs, and a RoleBinding in its namespace. A check with `kubectl auth can-i` proves only the RBAC rules. To prove the whole path, send requests from inside the Pod with the mounted token and CA file, and check both an allowed and a denied request.

On the server side, the API server runs as a static Pod from its manifest on the control-plane node, and the kubelet reads its own configuration file when it starts. The authorization mode should be `Node,RBAC`, the NodeRestriction admission plugin should be on, and anonymous access should be off where nothing needs it. The kubelet API on port 10250 needs anonymous access off, `Webhook` authorization, and the read-only port turned off. Network rules then limit each port to the hosts that need it.

An audit policy picks a level for each rule, and the first matching rule wins. Edit the API server manifest only with a backup stored outside its folder, and add a volume for every file that a new flag names.

Key facts to remember:

- The checks run in this order: authentication, authorization, admission.
- `401` is an authentication failure; `403` is an authorization failure.
- The ServiceAccount token proves identity, not permission.
- Set `--authorization-mode=Node,RBAC` and keep `NodeRestriction` in `--enable-admission-plugins`.
- Kubelet: `anonymous.enabled: false`, `authorization.mode: Webhook`, `readOnlyPort: 0`.
- Limit ports 6443, 10250, 2379 and 2380 to the hosts that need them.
- Audit Secrets at `Metadata` level and RBAC changes at `RequestResponse` level.

Clean up the playground when you finish.

<!-- astrona:playground:destroy -->
