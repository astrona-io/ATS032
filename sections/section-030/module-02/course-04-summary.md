---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Summary

This module covered how the Kubernetes API server identifies a caller, what an unidentified caller can do and how the identified caller is authorized.

The API server offers each request to its authentication methods: client certificates, ServiceAccount tokens, OpenID Connect tokens, webhook token authentication, a static token file and an authenticating proxy. The first method that accepts the credential produces a user name and groups. A client certificate cannot be revoked, and a static token file never expires, so both are weak choices for long-lived access. A decoded token shows claims but proves nothing, because only the API server checks the signature.

A request with no credential becomes `system:anonymous` in the group `system:unauthenticated` when `--anonymous-auth` is `true`, and then goes through authorization like any other. A request with a credential that fails verification returns `401` and is never treated as anonymous. The built-in role `system:public-info-viewer` lets anonymous callers read the health and version paths. Any other binding to `system:anonymous`, `system:unauthenticated` or `system:authenticated` opens data to the whole network or to every identity in the cluster, and the fix is to delete the binding, not to edit a built-in role.

Setting `--anonymous-auth=false` closes the last open paths but can break the probes of the API server Pod, so a structured authentication configuration that allows anonymous access only for the health paths is the safer middle route.

The `--authorization-mode` flag lists the authorizers in order. A hardened cluster uses `Node,RBAC`. `AlwaysAllow` removes the permission model, `ABAC` needs a restart for each change and `Webhook` hands the decision to an external service. Kubernetes has no user objects, so the name in a binding must match what the authenticator reports. Impersonation lets an allowed caller test or act as another identity. It is useful for checking a grant and dangerous when granted widely.

Clean up the playground when you finish.

<!-- astrona:playground:destroy -->
