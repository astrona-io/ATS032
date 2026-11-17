---
exam_objectives:
- Restrict access to Kubernetes API
---
# Remove RBAC Grants For Anonymous Requests

The bootstrap binds `view` to the group `system:unauthenticated` (ClusterRoleBinding `metrics-reader`) and `edit` to the user `system:anonymous` (RoleBinding `support-read`). The learner removes both and keeps the team binding `ops-viewer`.

The graders look for any binding outside the built-in `rbac-defaults` set that names an anonymous subject, send anonymous requests that must return 403, and check that `/version` stays public and `ops-viewer` still works.

The task and solution use a separate pinned kind cluster with one control plane node and one worker node (`examScope: cluster`). Run `astrona validate .` and `astrona test . --accept-terms --headless` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then `solution/apply.sh` applies the reference solution and `testing/wait-solved.sh` waits until every outcome passes.
