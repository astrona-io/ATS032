---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Remove Wildcards From A Group Role

Replace a wildcard rule in a group Role with explicit resources and verbs and verify allowed and denied actions. This independent graded environment is separate from the module playground.

Author checks: run `astrona validate -c ATS032/sections/section-010/module-03/labs/lab-01` from the workspace. In a fresh lab, run `testing/smoke.sh` with its private kubeconfig to confirm that the initial state fails, the reference solution passes and convergence completes. The grader requires Python 3 on the host.

Runtime verification is pending. Static checks and offline grader tests do not prove cluster execution.
