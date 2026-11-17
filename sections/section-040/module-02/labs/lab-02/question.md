---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Triage Vulnerability Records And Label Patch Waves

Allow about 10 minutes for the tasks.

The security team of the `starfleet` cluster sent a list of advisories. Some of them concern versions that the cluster runs, and some do not. Decide which records apply, then record the order in which the nodes will be patched.

## Connect to the lab

Use a shell on your own machine. The kubeconfig file holds the address and the credentials of this lab's cluster, and `kubectl` uses it.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-040-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-040-02-02" || exit 1
```

## Tasks

The ConfigMap `advisory-feed` in the namespace `starfleet-032-040-02-02` holds a table under the key `records`. Each row has an ID, a component, the first affected version (`INTRODUCED`) and the first fixed version (`FIXED`). The records are made up for this lab, and they change each time the lab starts. The components are:

- `kubelet`: the kubelet version of the nodes.
- `etcd`: the tag of the `etcd` image in `kube-system`.
- `coredns`: the tag of the CoreDNS image in `kube-system`.
- `busybox`: the tag of the image in the Deployment `probe` in `starfleet-032-040-02-02`.

Compare versions without a leading `v` and without a `-` suffix, so `v1.13.1` is `1.13.1` and `3.6.6-0` is `3.6.6`. A record applies when INTRODUCED ≤ running version < FIXED.

1. Create the ConfigMap `triage` in the namespace `starfleet-032-040-02-02` with the key `affected`. Its value lists the IDs of exactly the records that apply, separated by spaces, commas or new lines.
2. Label the nodes with the key `patch-wave` in the order that a Kubernetes upgrade must follow: `astro-ats-032-lab-040-02-02-control-plane` and `astro-ats-032-lab-040-02-02-worker` each get `1` or `2`.

Do not change `advisory-feed` or any workload.
