---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Run A Node Patch Window End To End

Capstone for the upgrade section: record the versions, clear a blocked drain, move a bare Pod, drain a worker, return it to service and verify the cluster.

The grader checks declared fields, the Pods and the node state. Run `testing/smoke.sh` with the lab's private kubeconfig to prove that the starting state fails and the reference result passes. Live verification is pending until a real container-engine run is recorded. Static checks are not runtime evidence.
