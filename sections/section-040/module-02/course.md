---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Track Vulnerabilities And Inventory Versions

An upgrade starts with two questions: which vulnerabilities affect this cluster, and which version does each component run? If you cannot answer both, you cannot decide how urgent an upgrade is. This module shows where Kubernetes publishes vulnerability information, how to build an inventory of the versions that run in a cluster, and how to turn a vulnerability announcement into a patch plan with a clear order of nodes.

A vulnerability is a flaw in software that an attacker can use. A **CVE** (Common Vulnerabilities and Exposures) is a public record of one such flaw. It has an identifier such as `CVE-2099-0001` (an example format, not a real record), a description, a list of affected and fixed versions, and a severity score. The Kubernetes project publishes the CVEs that affect Kubernetes itself. Your job is to match those records against what your cluster runs.

The module has three parts. **Where Vulnerabilities Are Published** lists the sources: the official CVE feed, the security announcements, release notes and patch releases. **Inventory What The Cluster Runs** reads the version of the API server, every node, the container runtime, the system components and the workload images. **Triage A Vulnerability And Plan Patch Waves** decides how urgent a fix is and records the order in which nodes will be patched.

## Learning objectives

After this module you can:

- Name the sources where Kubernetes publishes vulnerabilities, fixes and release changes.
- Read a CVE record: affected versions, fixed versions, severity and attack conditions.
- Build a version inventory of the API server, nodes, container runtime, system components and workload images from a live cluster.
- Explain why an image tag is not an exact identity and how an image digest differs.
- Decide the urgency of a fix and record the order in which nodes are patched.

## Before you start

You need Kubernetes basics: Pods, Deployments, nodes and `kubectl`. The playground is a `kind` cluster, whose nodes are containers. Every command in this module reads from the cluster or writes a small object, so all of them run in the playground. The commands that scan images with a separate tool are shown to read.

Your terminal must use the playground's private kubeconfig, the file that holds the cluster address and credentials for `kubectl`. Run these two commands once in every new terminal:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-040-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-040-02" || exit 1
```

The playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and two workers. Your own credentials have the `cluster-admin` role. The cluster starts with this content:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The Deployment `probe` with two replicas and a Service `probe`, and the Pod `shuttle`, a client with BusyBox tools. `shuttle` runs on the second worker |
| `outpost` | The Pod `drifter`, a client with BusyBox tools. It runs on the second worker |

The nodes are named `astro-ats-032-playground-040-02-control-plane`, `astro-ats-032-playground-040-02-worker` and `astro-ats-032-playground-040-02-worker2`.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
