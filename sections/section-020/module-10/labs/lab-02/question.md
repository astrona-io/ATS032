---
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions
  on newly created ones
---
# Replace a Legacy Token Secret With a Projected Token

Allow about 8 minutes for the tasks.

The `ledger-client` Pod in the `outpost` namespace reads a ServiceAccount token from a Secret. That token never expires and works for any audience. Replace it with a short-lived token that only the `ledger` service accepts.

## Connect to the lab

Use a shell on your own machine. The kubeconfig file holds the address and the credentials of this lab's cluster, and `kubectl` uses it.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-020-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-020-01-02" || exit 1
```

## Tasks

Work in the namespace `outpost-032-020-01-02`.

1. Recreate the Pod `ledger-client`. Keep the name, the ServiceAccount `reporter` and the image `docker.io/library/busybox:1.37.0`.
2. Give the new Pod a projected ServiceAccount token with the audience `ledger` and `expirationSeconds` of 600 or less. The container must read it at `/var/run/tokens/ledger-token`.
3. The new Pod must not mount any Secret volume, and it must set `automountServiceAccountToken: false`, so it has no token at `/var/run/secrets/kubernetes.io/serviceaccount`.
4. Delete the long-lived token Secret `reporter-legacy-token`. No Secret of type `kubernetes.io/service-account-token` for `reporter` may be left in the namespace.
5. The new Pod must be running and ready, and the API server must accept its token for the audience `ledger` as the ServiceAccount `reporter`.
