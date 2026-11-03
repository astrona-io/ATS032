---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Summary

This module covered how to learn which vulnerabilities affect a cluster and how to turn that knowledge into an ordered patch plan.

Kubernetes publishes its CVEs in an official feed that scripts can read, announces them on a security mailing list, and describes security fixes and urgent upgrade changes in the release notes. A record names the affected component, the affected and fixed versions, a CVSS severity and the conditions an attacker must meet. The vector matters as much as the number. Fixes arrive as patch releases, and a minor version receives them for about one year plus a two-month upgrade period. After that, the version gets no fixes.

A version inventory has one row for each layer and each node: the API server from the `/version` endpoint, the kubelet, runtime, operating system and kernel from `status.nodeInfo`, the control-plane and add-on versions from the images in `kube-system`, and the workload images from the Pod specifications. An image tag can move, so the digest in the container status is the exact identity of the content. A scanner such as Trivy compares image content with a vulnerability database, and its output is a list to triage.

Triage asks five questions: is an affected version running, is the vulnerable feature in use, can an attacker reach it, what does the attacker gain, and is a fix or a workaround available. The answers give a priority and a written reason. Patch waves put the control plane first and the nodes that are hardest to drain last. A label on each node keeps the plan in the cluster where a script can read it.

- Match each record against the version of the component it names, not only against the API server.
- Use digests when you need the exact content of an image.
- Write the reason for every priority decision.

Clean up the playground when you finish.

<!-- astrona:playground:destroy -->
