---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions
  on newly created ones
---
# Disable Unneeded ServiceAccount Tokens

Solve this question on: `terminal`

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

Allow 4–6 minutes for task work. Cluster startup adds time.

## Tasks

1. Create the ServiceAccount `no-api` in `starfleet-032-020-01-01` with `automountServiceAccountToken: false`.
2. Run the Pod `no-token-reader` in `starfleet-032-020-01-01` as `no-api`, with `automountServiceAccountToken: false` on the Pod as well. Keep the restricted security context and the writable scratch volume.
3. Wait until the Pod is Ready and confirm that the default token path `/var/run/secrets/kubernetes.io/serviceaccount` does not exist in it.

## Constraints

- Do not grant `no-api` any application permission.
- Keep the namespace, workload names and unrelated components.

## How the answer is checked

The grader runs two checks. The first checks that the ServiceAccount `no-api` does not mount a token. The second checks the fields of the Pod `no-token-reader` (ServiceAccount, automount, restricted security context, scratch volume), and that the token path is missing inside the running Pod. Both checks also ask the API server whether `no-api` can get Pods or Secrets, and fail if it can.
