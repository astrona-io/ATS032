---
exam_objectives:
- Restrict access to Kubernetes API
---
# Enforce Pod Security Standards On A Namespace

Allow about 10 minutes for the tasks.

The namespace `outpost-032-030-03-01` has no Pod Security labels, so the API server admits any Pod there, including privileged ones. The Deployment `web` in that namespace runs its container in privileged mode, although the application does not need it.

## Connect to the lab

Use a shell on your own machine. The kubeconfig file holds the address and the credentials of this lab's cluster, and `kubectl` uses it.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-030-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-030-03-01" || exit 1
```

## Tasks

1. Make the Pod Security admission controller enforce the `baseline` standard in the namespace `outpost-032-030-03-01`.
2. In the same namespace, make it warn about Pods that do not meet the `restricted` standard. Do not enforce `restricted`.
3. Change the Deployment `web` so that its container no longer runs in privileged mode. Keep the name, the image, the command and 2 replicas.

After the change, a new privileged Pod in the namespace must be rejected. A Pod that meets `baseline` but not `restricted` must be admitted with a warning. Both replicas of `web` must be ready.
