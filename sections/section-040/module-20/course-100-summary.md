# Summary

Before you can plan an upgrade, you must know which vulnerabilities affect the cluster and what the cluster runs. Then you can turn that knowledge into an ordered patch plan.

Kubernetes publishes its CVEs (Common Vulnerabilities and Exposures records) in an official feed that scripts can read. It announces them on a security mailing list, and it describes security fixes and urgent upgrade changes in the release notes. A record names the affected component, the affected and fixed versions, a CVSS (Common Vulnerability Scoring System) severity and the conditions an attacker must meet. The attack vector matters as much as the score.

Fixes arrive as patch releases. A minor version receives them for about one year, plus a two-month period to upgrade. After that, the version gets no more fixes.

A version inventory has one row for each layer and each node. The API server version comes from the `/version` endpoint. The kubelet, runtime, operating system and kernel come from `status.nodeInfo`. The control-plane and add-on versions come from the images in `kube-system`, and the workload images come from the Pod specifications.

An image tag can move, so the digest in the container status is the exact identity of the content. A scanner such as Trivy compares image content with a vulnerability database, and its output is a list of findings to triage.

Triage asks five questions: is an affected version running, is the vulnerable feature in use, can an attacker reach it, what does the attacker gain, and is a fix or a workaround available. The answers give a priority and a written reason. Patch waves put the control plane first and the nodes that are hardest to drain last. A label on each node keeps the plan in the cluster, where a script can read it.

Key facts to remember:

- Match each record against the version of the component it names, not only against the API server.
- Use digests when you need the exact content of an image.
- Write the reason for every priority decision.

Clean up the playground when you finish.

<!-- astrona:playground:destroy -->
