---
exam_objectives:
- Restrict access to Kubernetes API
---
# Make An Admission Webhook Fail Closed Safely

The bootstrap creates the ValidatingWebhookConfiguration `image-review` with `failurePolicy: Ignore`, `timeoutSeconds: 30` and no namespace selector. Its Service does not exist, and its `objectSelector` limits it to Pods labelled `review: image`, so a `Fail` setting cannot lock the cluster.

The graders check the fields, evaluate the namespace selector against the live namespace labels, and send labelled dry-run Pods: rejected in `starfleet-032-030-03-03`, admitted in `kube-system`.

The task and solution use a separate pinned kind cluster with one control plane node and one worker node (`examScope: cluster`). Run `astrona validate .` and `astrona test . --accept-terms --headless` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then `solution/apply.sh` applies the reference solution and `testing/wait-solved.sh` waits until every outcome passes.
