---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Drain And Return A Worker To Service

Respect disruption limits while draining and returning an isolated worker to service.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
