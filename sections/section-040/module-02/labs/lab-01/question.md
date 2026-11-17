---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Record A Cluster Version Inventory With Image Digests

Allow about 8 minutes for the tasks.

A security announcement lists fixed versions for several components. Before the team can say whether the `starfleet` cluster is affected, it needs one record of what the cluster runs now.

## Connect to the lab

Use a shell on your own machine. The kubeconfig file holds the address and the credentials of this lab's cluster, and `kubectl` uses it.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-040-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-040-02-01" || exit 1
```

## Tasks

The cluster has the control plane node `astro-ats-032-lab-040-02-01-control-plane` and the worker node `astro-ats-032-lab-040-02-01-worker`. The Deployment `probe` in the namespace `starfleet-032-040-02-01` runs two Pods. Read every value from the live cluster; the values in this lab differ from run to run.

Create the ConfigMap `version-inventory` in the namespace `starfleet-032-040-02-01` with these keys:

1. `server-version`: the `gitVersion` of the API server, for example `v1.35.0`. `kubelet-control-plane` and `kubelet-worker`: the kubelet version of each node. `container-runtime`: the container runtime version of the worker, exactly as the node reports it.
2. `etcd-image` and `coredns-image`: the full image of the `etcd` Pod and of a CoreDNS Pod in `kube-system`, with registry and tag.
3. `probe-image`: the image of the container in the Deployment `probe`, exactly as the Deployment writes it. `probe-digest`: the image digest that the running `probe` Pods report, written `sha256:` followed by 64 hexadecimal characters.

Do not change any workload.
