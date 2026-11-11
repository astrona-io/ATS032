---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Enforce Admission Rules In A Namespace

Make the API server reject privileged Pods and NodePort Services in one namespace and still admit ordinary objects. The task and reference solution use a separate pinned kind cluster. The grader checks declared fields and bounded live evidence. Python 3 is required on the grading host.

Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
