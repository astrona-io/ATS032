---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Prerequisites

Use astrona, kubectl, Python 3, Podman and a shell.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-020-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-020-02-01" || exit 1
```

Keep this connection selected. Every script supplied by the lab refuses a different context.
