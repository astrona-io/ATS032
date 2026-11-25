---
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions
  on newly created ones
---
# Give a Deployment Its Own ServiceAccount

Allow about 6 minutes for the tasks.

The `probe` web server in the `starfleet` namespace never calls the Kubernetes API, but its Pods run as the `default` ServiceAccount and get an API token. Give the Deployment its own ServiceAccount that mounts no token.

## Connect to the lab

Use a shell on your own machine. The kubeconfig file holds the address and the credentials of this lab's cluster, and `kubectl` uses it.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-020-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-020-02-01" || exit 1
```

## Tasks

Work in the namespace `starfleet-032-020-02-01`.

1. Create the ServiceAccount `probe` with `automountServiceAccountToken: false`. Do not give it any permission: no Role, ClusterRole or binding may reach it.
2. Change the Deployment `probe` so that its Pods run as the ServiceAccount `probe`. Keep two replicas.
3. Wait until the rollout is complete. Both running Pods of the Deployment must use `probe` and must have no directory `/var/run/secrets/kubernetes.io/serviceaccount`.
