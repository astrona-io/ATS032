---
exam_objectives:
- Restrict access to Kubernetes API
---
# Remove Static Token Authentication From The API Server

The bootstrap writes a static token file with a `system:masters` token and adds `--token-auth-file` to the kube-apiserver static Pod (`bootstrap/stage-token.sh` runs inside the control plane container). It keeps a copy of the token in `/var/lib/ats-032-lab` for the grader.

The graders check that the flag and the file are gone, that the old token gets 401, and that the restarted API server is Ready. The bootstrap and the solution wait up to three minutes for the API server restart.

The task and solution use a separate pinned kind cluster with one control plane node and one worker node (`examScope: cluster`). Run `astrona validate .` and `astrona test . --accept-terms --headless` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then `solution/apply.sh` applies the reference solution and `testing/wait-solved.sh` waits until every outcome passes.
