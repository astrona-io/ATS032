---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Give Each Workload Its Own Least-Privilege ServiceAccount

Move one workload to a dedicated ServiceAccount without a token, create a ServiceAccount that has one narrow grant, and remove the grant from the default account.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify the initial rejection and the reference success. Static validation is not live evidence. Runtime verification remains pending.
