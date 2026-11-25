# Upgrade Kubernetes To Avoid Vulnerabilities

Kubernetes publishes security fixes only for its newest releases. A cluster that stays on an old version keeps every known flaw in that version, and those flaws are public. Upgrading is therefore a security control, not only maintenance.

An upgrade is also a risky operation. A node that is taken out of service at the wrong time can stop an application, and a failed upgrade can leave the cluster broken. In this section, you learn how to upgrade safely: what the version rules are, how to move work off a node, how to upgrade with kubeadm, how to plan patches for a vulnerability, and how to prove the cluster works afterwards.

## What you will learn

The section moves from one upgrade to a complete patch process:

- **Upgrade Kubernetes To Avoid Vulnerabilities.** Versions and the allowed version differences between components, draining a node while a PodDisruptionBudget protects the application, the kubeadm upgrade sequence, and the etcd snapshot taken before an upgrade.
- **Track Vulnerabilities And Inventory Versions.** Where vulnerabilities are published, how to record the versions a cluster runs, and how to sort a vulnerability into waves of patches.
- **Patch Nodes And Verify The Upgraded Cluster.** Patching the operating system and the container runtime on nodes, checking a cluster after maintenance, and the limits of rolling back.

## How this section works

Each module has its own playground. The upgrade and patch modules use a virtual machine (VM) with a one-node Kubernetes cluster built with kubeadm, the standard tool that installs and upgrades a cluster on a Linux machine. The vulnerability module uses a private `kind` cluster with Kubernetes v1.35. Start the playground from the first page of the module and keep it running while you read.

When a page teaches a skill you can be graded on, a lab comes right after it. A lab gives you a short task in a fresh cluster and checks your result. Each module ends with a summary and a short knowledge check.

## By the end of this section

You will be able to:

- state the version skew rules and the upgrade order;
- cordon, drain and uncordon a node, and explain a PodDisruptionBudget;
- write the kubeadm upgrade commands for each type of node;
- take and check an etcd snapshot, and verify the cluster after an upgrade;
- find published vulnerabilities, record the versions a cluster runs, and plan waves of patches;
- patch node software one node at a time and return each node to service;
- verify a cluster in layers after maintenance, and repair a node that was left cordoned or tainted;
- decide between fixing forward and restoring from a snapshot, and prove the restore with a drill;
- restart the container runtime on a drained node and return the node to service.
