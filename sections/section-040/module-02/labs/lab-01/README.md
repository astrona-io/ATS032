---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Record The Version Inventory And Patch Waves

Read the real versions of a cluster, record them in one ConfigMap and label each node with its patch wave.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
