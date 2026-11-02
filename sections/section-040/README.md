---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Upgrade Kubernetes To Avoid Vulnerabilities

Security fixes reach only supported versions, so upgrading is a security control. This section explains versions and skew, shows how to drain a node while a PodDisruptionBudget protects the application, lists the kubeadm upgrade sequence, and covers the etcd snapshot taken before an upgrade and the checks made after it.

The section has one module. Read the landing page, then the parts in order, and use the playground next to the text. The lab follows the part it practises, and the summary closes the module. A ten-question knowledge check follows the summary.

## Learning Outcomes

- State the version skew rules and the upgrade order.
- Cordon, drain and uncordon a node and explain a PodDisruptionBudget.
- Write the kubeadm upgrade commands for each node type.
- Take and check an etcd snapshot and verify the cluster after an upgrade.
