---
exam_objectives:
- Restrict access to Kubernetes API
---
# Enforce Pod Security Standards On A Namespace

The bootstrap creates `outpost-032-030-03-01` without Pod Security labels and a privileged Deployment `web`.

The graders check the labels and send server-side dry-run Pods: a privileged Pod must be rejected, a plain Pod must be admitted with a `restricted` warning. `web` must roll out without privileged containers.

The task and solution use a separate pinned kind cluster with one control plane node and one worker node (`examScope: namespace`). Run `astrona validate .` and `astrona test . --accept-terms --headless` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then `solution/apply.sh` applies the reference solution and `testing/wait-solved.sh` waits until every outcome passes.
