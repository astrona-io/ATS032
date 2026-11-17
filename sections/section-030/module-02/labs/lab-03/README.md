---
exam_objectives:
- Restrict access to Kubernetes API
- Use Role Based Access Controls to minimize exposure
---
# Remove AlwaysAllow And Narrow Impersonation Rights

The bootstrap appends `AlwaysAllow` to `--authorization-mode` (`bootstrap/stage-authorization.sh` runs inside the control plane container) and gives the group `helpdesk` `impersonate` on users, groups and ServiceAccounts through a ClusterRoleBinding. With `AlwaysAllow` the API server turns anonymous authentication off, so the kubelet's anonymous HTTPS probes would get 401 and the Pod would never be ready; the bootstrap therefore changes the three probes to TCP checks on the same port.

The graders read the flag in the manifest and in the running Pod, and send SubjectAccessReviews: a user without rules must not list Secrets, and `helpdesk` may impersonate only the ServiceAccount `probe` in `starfleet-032-030-02-03`, with an `RBAC:` reason.

The task and solution use a separate pinned kind cluster with one control plane node and one worker node (`examScope: cluster`). Run `astrona validate .` and `astrona test . --accept-terms --headless` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then `solution/apply.sh` applies the reference solution and `testing/wait-solved.sh` waits until every outcome passes.
