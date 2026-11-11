---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Remove Anonymous Access To The API

Close the binding that lets unauthenticated callers read cluster data while keeping health and version access and the binding of a named team. The task and reference solution use a separate pinned kind cluster. The grader checks declared fields and bounded live evidence. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
