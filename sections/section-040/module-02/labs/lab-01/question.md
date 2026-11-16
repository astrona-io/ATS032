---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Record The Version Inventory And Patch Waves

Solve this question on: `terminal`

A security announcement lists the fixed versions of a Kubernetes release. Before anyone plans the upgrade, the team needs one record of what the cluster runs now and the order in which the nodes will be patched.

## Starting state

The isolated environment has one control-plane node and two workers. The namespace `starfleet-032-040-02-01` runs the Deployment `probe` and the Pod `shuttle`. The namespace `outpost-032-040-02-01` runs the Pod `drifter`. No inventory exists.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-040-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-040-02-01" || exit 1
```

Keep this connection selected. Every script supplied by the lab refuses a different context.

Allow 8–10 minutes for task work. Cluster startup with two workers adds time.

## Tasks

1. Create the ConfigMap `version-inventory` in the namespace `starfleet-032-040-02-01` with exactly these keys: `server-version` (the `gitVersion` of the API server), `kubelet-control-plane`, `kubelet-worker` and `kubelet-worker2` (the kubelet version of each node), `container-runtime` (the container runtime version of the control-plane node), `probe-image` (the image of the container in the Deployment `probe`) and `client-image` (the image of the container in the Pod `drifter`).
2. Label the three nodes with the key `patch-wave`: the control-plane node gets `1`, the first worker gets `2` and the second worker gets `3`. The second worker goes last because it runs the client Pods, which have no controller and cannot be moved by a drain.

## Constraints

- Read the values from the live cluster. Do not type them from memory.
- Do not change any workload. This exercise records versions; it does not upgrade anything.

## How the answer is checked

The grader runs two checks. The first reads the same fields from the cluster and compares them with your ConfigMap. The second checks the three `patch-wave` labels. Both checks also confirm that the Deployment `probe` is unchanged and that `shuttle` still reaches `http://probe/`.
