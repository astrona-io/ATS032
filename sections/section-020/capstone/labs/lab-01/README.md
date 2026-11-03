---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Harden ServiceAccounts Across Two Namespaces

Give each workload its own identity, remove the grants and tokens that a review found, and prove the result with allowed and denied permission checks.

Capstone for ServiceAccount hardening: a dedicated account, a narrow grant, the default account, a legacy token and a group binding. The grader checks declared fields, permission checks and the token files in the containers. Run `testing/smoke.sh` with the lab's private kubeconfig to prove that the starting state fails and the reference result passes. Live verification is pending. Static checks are not runtime evidence.
