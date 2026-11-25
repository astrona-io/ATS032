---
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions
  on newly created ones
---
# Grant a ServiceAccount Least-Privilege Access

Allow about 10 minutes for the tasks.

The `shuttle` Pod in the `starfleet` namespace must read the list of Pods in its own namespace, and nothing else. Give it a ServiceAccount with exactly that permission and a short-lived token.

## Connect to the lab

Use a shell on your own machine. The kubeconfig file holds the address and the credentials of this lab's cluster, and `kubectl` uses it.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-020-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-020-02-02" || exit 1
```

## Tasks

1. In the namespace `starfleet-032-020-02-02`, create the ServiceAccount `shuttle-reader` with `automountServiceAccountToken: false`.
2. Give `shuttle-reader` permission to `get` and `list` Pods in `starfleet-032-020-02-02`. It must get no other permission there, and no permission at all in the namespace `outpost-032-020-02-02`.
3. Recreate the Pod `shuttle` in `starfleet-032-020-02-02` so that it runs as `shuttle-reader` and sets `automountServiceAccountToken: false`. Keep the name and the image `docker.io/library/busybox:1.37.0`.
4. Give the new Pod a projected ServiceAccount token with `expirationSeconds` of 900 or less, which the container reads at `/var/run/tokens/token`. Use the default audience, so that the API server accepts the token.
5. The new Pod must be running and ready, and must have no directory `/var/run/secrets/kubernetes.io/serviceaccount`.
