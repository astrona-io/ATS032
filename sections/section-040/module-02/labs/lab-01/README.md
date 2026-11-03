---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Record The Version Inventory And Patch Waves

Read the real versions of a cluster, record them in one ConfigMap and label each node with its patch wave.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. The grader compares the recorded values with the live cluster. Static validation is not live evidence. Runtime verification remains pending.
