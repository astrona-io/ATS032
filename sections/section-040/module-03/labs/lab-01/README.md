---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Verify And Repair A Cluster After Maintenance

Find the leftovers of an unfinished maintenance window, repair them and record the verified state.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
