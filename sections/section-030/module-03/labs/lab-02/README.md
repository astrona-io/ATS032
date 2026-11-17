---
exam_objectives:
- Restrict access to Kubernetes API
---
# Block NodePort Services With A ValidatingAdmissionPolicy

The bootstrap creates the policy `deny-nodeport` for `CREATE` only and no binding. The learner adds `UPDATE` and the binding `deny-nodeport-outpost`.

The graders test behaviour, not the policy text: server-side dry-run creates and a dry-run patch of the Service `web`, repeated for a few seconds while a new binding loads. The denial must name the binding, and `starfleet-032-030-03-02` must stay open.

The task and solution use a separate pinned kind cluster with one control plane node and one worker node (`examScope: cluster`). Run `astrona validate .` and `astrona test . --accept-terms --headless` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then `solution/apply.sh` applies the reference solution and `testing/wait-solved.sh` waits until every outcome passes.
