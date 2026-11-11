---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Grant Namespace Pod Read Access

Solve this question on: `terminal`

The `starfleet-032-010-01-01` application needs this task completed in its isolated lab environment.

## Objective

Grant a ServiceAccount only Pod read access in the required namespace and verify denied operations.

## Starting state

The `starfleet-032-010-01-01` and `outpost-032-010-01-01` namespaces and `starfleet-032-010-01-01/shuttle` ServiceAccount exist. A ServiceAccount identifies a workload when it calls the Kubernetes application programming interface (API). It has no application-specific Pod read grant.

Use this lab's private kubeconfig. A kubeconfig contains the cluster address and credentials used by kubectl, the Kubernetes command-line tool. The lab has a separate kind cluster from the module playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-010-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-010-01-01" || exit 1
```

Keep this connection selected for every command below.

Allow 3–5 minutes for task work. Cluster startup adds time.

## Tasks

1. Create the Role `pod-reader` in `starfleet-032-010-01-01` that grants exactly `get`, `list` and `watch` on core Pods.
2. Create the RoleBinding `shuttle-pod-reader` in `starfleet-032-010-01-01` that gives the Role `pod-reader` to the ServiceAccount `shuttle` in `starfleet-032-010-01-01` and to no one else.
3. Prove the grant with `kubectl auth can-i --as=system:serviceaccount:starfleet-032-010-01-01:shuttle`: `shuttle` can list Pods in `starfleet-032-010-01-01`, and cannot create or delete Pods, read Secrets, read Pods in `outpost-032-010-01-01` or read nodes.

## Constraints

- Do not add a ClusterRoleBinding or any other grant.
- Keep the namespaces and the ServiceAccount `shuttle`.

## How the answer is checked

The grader runs two checks. The first checks that the Role `pod-reader` has one rule: `get`, `list` and `watch` on core Pods. The second checks that the RoleBinding `shuttle-pod-reader` references that Role and only `shuttle`, and that `shuttle` can get, list and watch Pods. Both checks also ask the API server whether `shuttle` can create or delete Pods, read Secrets, read Pods in `outpost-032-010-01-01` or read nodes, and fail if it can.
