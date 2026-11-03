---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Remediate An RBAC Review Across Three Namespaces

Capstone for RBAC: a cluster-wide edit grant, a binding to every authenticated identity, a wildcard Role and an aggregated ClusterRole bound in one namespace. The grader checks the declared fields, searches every binding for the identities and tests allowed and denied actions. Python 3 is required on the grading host.

Run `testing/smoke.sh` with the lab's private kubeconfig to prove that the starting state fails and the reference result passes. Each wait is bounded. Live verification is pending until a real container-engine run is recorded. Static checks are not runtime evidence.
