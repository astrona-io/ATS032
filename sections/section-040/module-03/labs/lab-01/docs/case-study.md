---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Starting Environment

A maintenance window on the second worker ended without a final check. The node is still cordoned and still has a taint, one replica of the Deployment `probe` is not running, and the PodDisruptionBudget would block the next drain.
