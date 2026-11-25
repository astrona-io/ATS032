# Track Vulnerabilities And Inventory Versions

Every upgrade starts with two questions. Which vulnerabilities affect this cluster? Which version does each component run? If you cannot answer both, you cannot decide how urgent an upgrade is.

A vulnerability is a flaw in software that an attacker can use. A **CVE** (Common Vulnerabilities and Exposures) is a public record of one such flaw. It has an identifier such as `CVE-2099-0001` (an example format, not a real record), a description, a list of affected and fixed versions, and a severity score. The Kubernetes project publishes the CVEs that affect Kubernetes itself. Your job is to match those records against what your cluster runs.

This module shows where Kubernetes publishes vulnerability information and how to build an inventory of the versions that run in a cluster. It then shows how to turn a vulnerability announcement into a patch plan with a clear order of nodes.

## What you will learn

After this module, you can:

- name the sources where Kubernetes publishes vulnerabilities, fixes and release changes;
- read a CVE record: affected versions, fixed versions, severity and attack conditions;
- build a version inventory of the API server, nodes, container runtime, system components and workload images from a live cluster;
- explain why an image tag is not an exact identity and how an image digest differs;
- decide the urgency of a fix and record the order in which nodes are patched.

## How the module is laid out

You start with **Where Vulnerabilities Are Published**, which lists the sources: the official CVE feed, the security announcements, the release notes and the patch releases. **Inventory What The Cluster Runs** then reads the version of the API server, every node, the container runtime, the system components and the workload images. **Triage A Vulnerability And Plan Patch Waves** closes the module. It decides how urgent a fix is and records the order in which the nodes are patched.

## Before you start

You should know the Kubernetes basics: Pods, Deployments, nodes and `kubectl`. The playground is a `kind` cluster, and its nodes are containers. Every command in this module reads from the cluster or writes a small object, so all of them run in the playground. The commands that scan images with a separate tool are shown for you to read only.

Your terminal must use the private kubeconfig of the playground. A kubeconfig is the file that holds the cluster address and the credentials for `kubectl`. Run these two commands once in every new terminal:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-040-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-040-02" || exit 1
```

## Your playground

Your playground is a `kind` cluster that runs Kubernetes 1.35 with one control-plane node and two workers. Your own credentials have the `cluster-admin` role. The cluster starts with these objects:

| Namespace | Object | What it is |
| --- | --- | --- |
| `starfleet` | `probe` Deployment, two replicas, label `app: probe` | A small Python web server on port 8080, built from the image `python:3.13-alpine` |
| `starfleet` | `probe` Service | Port 80, forwards to port 8080 of the `probe` pods |
| `starfleet` | `probe-code` ConfigMap | Holds the code of the `probe` web server |
| `starfleet` | `shuttle` Pod, label `app: shuttle` | A client with BusyBox tools. It is a bare Pod and runs on the second worker |
| `outpost` | `drifter` Pod, label `app: drifter` | A client with BusyBox tools. It is a bare Pod and runs on the second worker |

The nodes are named `astro-ats-032-playground-040-02-control-plane`, `astro-ats-032-playground-040-02-worker` and `astro-ats-032-playground-040-02-worker2`.

Start your playground now and keep it running while you read:

<!-- astrona:playground -->
