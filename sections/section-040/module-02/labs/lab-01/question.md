---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Record The Version Inventory And Patch Waves

A security announcement lists the fixed versions of a Kubernetes release. Before anyone plans the upgrade, the team needs one record of what the cluster runs now and the order in which the nodes will be patched.

## Starting state

The isolated environment has one control-plane node and two workers. The namespace `starfleet` runs the Deployment `probe` and the Pod `shuttle`. The namespace `outpost` runs the Pod `drifter`. No inventory exists.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-040-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-040-02-01" || exit 1
```

Keep this connection selected. Every script supplied by the lab refuses a different context.

## Required result

Read the values from the live cluster. Do not type them from memory.

1. Create the ConfigMap `version-inventory` in the namespace `starfleet` with exactly these keys: `server-version` (the `gitVersion` of the API server), `kubelet-control-plane`, `kubelet-worker` and `kubelet-worker2` (the kubelet version of each node), `container-runtime` (the container runtime version of the control-plane node), `probe-image` (the image of the container in the Deployment `probe`) and `client-image` (the image of the container in the Pod `drifter`).
2. Label the three nodes with the key `patch-wave`: the control-plane node gets `1`, the first worker gets `2` and the second worker gets `3`. The second worker goes last because it runs the client Pods, which have no controller and cannot be moved by a drain.

Do not change any workload. This exercise records versions; it does not upgrade anything.

## Verify The Result

The grader reads the same fields from the cluster and compares them with your ConfigMap, then checks the three labels. Check your own values against the live cluster before you submit.
