---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Rewrite A Broad Grant As Least Privilege

Replace a cluster-wide ClusterRoleBinding with a namespaced Role and RoleBinding and verify allowed and denied actions. This independent graded environment is separate from the module playground.

Author checks: run `astrona validate -c ATS032/sections/section-010/module-02/labs/lab-01` from the workspace. In a fresh lab, run `testing/smoke.sh` with its private kubeconfig to confirm that the initial state fails, the reference solution passes and convergence completes. The grader requires Python 3 on the host.

Runtime verification is pending. Static checks and offline grader tests do not prove cluster execution.
