---
exam_objectives:
- Restrict access to Kubernetes API
---
# Harden The Kubelet On A Worker Node

The bootstrap turns on anonymous kubelet access, `AlwaysAllow` authorization and the read-only port 10255 on the worker node (`bootstrap/weaken-kubelet.sh` runs inside the worker container). The learner edits `/var/lib/kubelet/config.yaml` and restarts the kubelet.

The graders read the effective configuration through the `configz` endpoint, call port 10250 without credentials (must be 401) and port 10255 (must refuse the connection), and check that the node is Ready and the Pod `probe` still runs.

The task and solution use a separate pinned kind cluster with one control plane node and one worker node (`examScope: cluster`). Run `astrona validate .` and `astrona test . --accept-terms --headless` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then `solution/apply.sh` applies the reference solution and `testing/wait-solved.sh` waits until every outcome passes.
