---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Use A Workload Identity For An API Request

Run the application with a narrow identity and authenticate a real API request from its container. The task and reference solution use a separate pinned kind cluster. The grader checks declared fields and bounded live evidence. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
