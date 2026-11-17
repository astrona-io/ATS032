---
exam_objectives:
- Restrict access to Kubernetes API
---
# Give A Workload A Narrow ServiceAccount

Give the Deployment `probe` its own ServiceAccount `observer`, bound to a Role that may only get and list Pods in `starfleet-032-030-01-01`.

The graders compare the Role verbs as a set, look for extra grants, and send real API requests from inside a `probe` Pod with its mounted token: Pods return 200, Secrets and the `outpost-032-030-01-01` Services return 403.

The task and solution use a separate pinned kind cluster with one control plane node and one worker node (`examScope: namespace`). Run `astrona validate .` and `astrona test . --accept-terms --headless` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then `solution/apply.sh` applies the reference solution and `testing/wait-solved.sh` waits until every outcome passes.
