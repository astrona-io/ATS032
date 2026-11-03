---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Restrict API Access End To End

Give a workload a narrow identity, remove anonymous access to the API and add admission rules to a namespace, and prove each result with requests. The task and reference solution use a separate pinned kind cluster. The grader checks declared fields and bounded live evidence. Python 3 is required on the grading host.

Run `testing/smoke.sh` with the lab's private kubeconfig to prove that the starting state fails and the reference repair passes. Each wait and request is bounded. Live verification is pending until actual container-engine execution is recorded. Static checks are not runtime evidence.
