---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Summary

A ServiceAccount is the identity of a workload inside one namespace. A pod that names no account receives `default`, and the kubelet mounts a projected volume with a token, the cluster certificate authority and the namespace at `/var/run/secrets/kubernetes.io/serviceaccount`. A new `default` account has almost no permissions. The risk is the mounted token in every container and any grant that someone later adds to `default`.

The field `automountServiceAccountToken` controls the mount. The pod setting wins over the ServiceAccount setting, and with neither set the token is mounted. The value is read when the pod is created, so patching a ServiceAccount does not change running pods. Checking a pod means looking for the directory inside the container, never printing the token. Mounting and permissions are separate: a new account should start with no grants, one account should serve one workload, and no role should be bound to `default` or to the groups that contain all ServiceAccounts.

A workload that must call the API receives a bound token. The TokenRequest API creates it on demand with an expiry time, an audience and, if requested, a bound object. A projected volume sets `audience`, `expirationSeconds` and `path`, and the kubelet renews the file. `kubectl create token` requests one directly, with a minimum lifetime of ten minutes.

The legacy token Secret of type `kubernetes.io/service-account-token` has no expiry, no audience and no binding. Kubernetes no longer creates it automatically, but a user can still create one, and a review lists them with a field selector on the Secret type.

Key facts to remember:

- Pod-level `automountServiceAccountToken` overrides the ServiceAccount field.
- The default projected token lives about one hour and is renewed by the kubelet.
- A token for another audience is not accepted by the API server.
- Long-lived token Secrets are a finding; short-lived bound tokens are the replacement.

<!-- astrona:playground:destroy -->
