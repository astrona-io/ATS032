---
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions
  on newly created ones
---
# Remove Long-Lived ServiceAccount Tokens

Allow about 8 minutes for the tasks.

A token review of the `outpost` namespace found credentials that live far too long: Secrets that hold tokens without an expiry time, and a Pod whose token is valid for a whole day. Remove them.

## Connect to the lab

Use a shell on your own machine. The kubeconfig file holds the address and the credentials of this lab's cluster, and `kubectl` uses it.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-020-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-020-03-02" || exit 1
```

## Tasks

Work in the namespace `outpost-032-020-03-02`.

1. Find and delete every Secret of type `kubernetes.io/service-account-token` in the namespace. Keep the ordinary Secret `ledger-settings`.
2. The Pod `ledger-client` reads a projected token that is valid for 86400 seconds. Recreate it with `expirationSeconds` of 3600 or less. Keep the name, the ServiceAccount `ledger`, the image `docker.io/library/busybox:1.37.0`, `automountServiceAccountToken: false` and the token path `/var/run/tokens/token`.
3. The new Pod must be running and ready, and the API server must accept its token as the ServiceAccount `ledger`.
