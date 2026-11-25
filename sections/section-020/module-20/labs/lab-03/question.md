---
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions
  on newly created ones
---
# Lock Down the Default ServiceAccount

Allow about 8 minutes for the tasks.

In the `starfleet` and `outpost` namespaces, someone gave the `default` ServiceAccount permissions to fix an old error. Every Pod that does not name a ServiceAccount now gets those permissions and a token. Take them away.

## Connect to the lab

Use a shell on your own machine. The kubeconfig file holds the address and the credentials of this lab's cluster, and `kubectl` uses it.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-020-02-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-020-02-03" || exit 1
```

## Tasks

The namespaces are `starfleet-032-020-02-03` and `outpost-032-020-02-03`.

1. Remove every permission of the `default` ServiceAccount in both namespaces. No RoleBinding or ClusterRoleBinding may reach either `default` ServiceAccount. Keep the Role `pod-access` in `starfleet-032-020-02-03`; only its binding must go.
2. Set `automountServiceAccountToken: false` on the `default` ServiceAccount of both namespaces.
3. Recreate the Pod `shuttle` in `starfleet-032-020-02-03` and the Pod `drifter` in `outpost-032-020-02-03` with the same names and the image `docker.io/library/busybox:1.37.0`. Both must be running and ready, and neither may have a ServiceAccount token: no directory `/var/run/secrets/kubernetes.io/serviceaccount` and no projected token volume.
