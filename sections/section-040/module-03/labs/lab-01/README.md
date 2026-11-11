---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Verify And Repair A Cluster After Maintenance

Find the leftovers of an unfinished maintenance window, repair them and record the verified state.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
