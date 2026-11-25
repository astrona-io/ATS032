---
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions
  on newly created ones
---
# Disable Unneeded ServiceAccount Tokens

Allow about 6 minutes for the tasks.

The `starfleet` team runs a small reader Pod that never calls the Kubernetes API. It still receives an API token, because it runs as the `default` ServiceAccount. Give it an identity that gets no token at all.

## Connect to the lab

Use a shell on your own machine. The kubeconfig file holds the address and the credentials of this lab's cluster, and `kubectl` uses it.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-020-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-020-01-01" || exit 1
```

## Tasks

Work in the namespace `starfleet-032-020-01-01`.

1. Create the ServiceAccount `no-api`. Set it so that Pods which use it do not get a ServiceAccount token mounted.
2. Do not give `no-api` any permission: no Role, ClusterRole or binding may reach it.
3. The Pod `no-token-reader` runs as the `default` ServiceAccount and has a token. Recreate it so that it runs as `no-api` and also sets `automountServiceAccountToken: false` in its own Pod spec. Keep the Pod name, the container `reader` and its image `docker.io/library/busybox:1.37.0`.
4. The new Pod must be running and ready. Its container must have no ServiceAccount token: the directory `/var/run/secrets/kubernetes.io/serviceaccount` must not exist, and no volume may project a token.
