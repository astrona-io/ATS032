---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Use A Workload Identity For An API Request

Solve this question on: `terminal`

Run the application with a narrow identity and authenticate a real API request from its container. Use the isolated `starfleet-032-030-01-01` environment to verify the result.

## Objective

Run the application with a narrow identity and authenticate a real API request from its container.

## Starting state

The application and client fixtures are healthy. Complete the required change without replacing unrelated resources.

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-030-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-030-01-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

Allow 6–8 minutes for task work. Cluster startup adds time.

## Tasks

1. Create the ServiceAccount `observer`, the Role `observer-reader` granting exactly `get` and `list` on core Pods, and the RoleBinding `observer-read` that gives the Role to `observer`, all in `starfleet-032-030-01-01`.
2. Run both `probe` replicas as the ServiceAccount `observer`.
3. From the application container, send a request with its mounted token and certificate authority that reads the Pod list of `starfleet-032-030-01-01`.

## Constraints

- `observer` must not read Secrets or create Pods.
- Do not replace unrelated resources.

## How the answer is checked

The grader runs two checks. The first checks the ServiceAccount `observer`, the Role `observer-reader` and the RoleBinding `observer-read`. The second checks that the Deployment `probe` runs as `observer` and runs the request from task 3 in a `probe` container, which must return a Pod list. Both checks also ask the API server whether `observer` can read Secrets or create Pods, and fail if it can.
