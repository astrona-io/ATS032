---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Upgrade Kubernetes To Avoid Vulnerabilities

Security fixes reach only supported versions, so upgrading is a security control. This section explains versions and skew, shows how to drain a node while a PodDisruptionBudget protects the application, lists the kubeadm upgrade sequence, and covers the etcd snapshot taken before an upgrade and the checks made after it.

The section has three modules and a capstone lab. The first module covers versions, draining, the kubeadm sequence and the etcd snapshot. The second module covers where vulnerabilities are published, how to inventory the versions a cluster runs and how to triage a vulnerability into patch waves. The third module covers patching the operating system and container runtime on nodes, verifying a cluster after maintenance and the limits of rolling back.

Read each landing page, then the parts in order, and use the playground next to the text. Each lab follows the part it practises, and each summary closes its module. A ten-question knowledge check follows each summary. The capstone lab at the end of the section combines the skills of all three modules.

## Learning Outcomes

- State the version skew rules and the upgrade order.
- Cordon, drain and uncordon a node and explain a PodDisruptionBudget.
- Write the kubeadm upgrade commands for each node type.
- Take and check an etcd snapshot and verify the cluster after an upgrade.
- Find published vulnerabilities, record the versions that a cluster runs and plan patch waves.
- Patch node software one node at a time and return each node to service.
- Verify a cluster in layers after maintenance and repair a node that was left cordoned or tainted.
- Decide between fixing forward and restoring from a snapshot, and prove the restore with a drill.
- Run a node patch window end to end in the capstone lab.
