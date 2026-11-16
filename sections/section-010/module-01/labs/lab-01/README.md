---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Grant Namespace Pod Read Access

Grant a ServiceAccount only Pod read access in the required namespace and verify denied operations. This independent graded environment is separate from the module playground.

Author checks: run `astrona validate -c ATS032/sections/section-010/module-01/labs/lab-01` from the workspace. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass. The grader requires Python 3 on the host.

Runtime verification is pending. Static checks and offline grader tests do not prove cluster execution.
