---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Remove ServiceAccount Findings From A Namespace

Remove the over-broad grants, the long-lived token Secret and the long projected token from a namespace, and keep the one permission the workload needs.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
