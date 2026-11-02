---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Drain And Return A Worker To Service

Respect disruption limits while draining and returning an isolated worker to service.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
