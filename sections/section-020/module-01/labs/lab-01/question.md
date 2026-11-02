---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions
  on newly created ones
---
# Disable Unneeded ServiceAccount Tokens

Run a workload without mounting credentials it does not need.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-020-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-020-01-01" || exit 1
node_name="astro-ats-032-lab-020-01-01-control-plane"
worker_name="astro-ats-032-lab-020-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Create ServiceAccount no-api with automountServiceAccountToken false. Run no-token-reader as that account with Pod-level automount also false. Keep the restricted security context and writable scratch volume. The Pod must be Ready and the default service-account token path must not exist. Do not grant this identity application permissions.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
