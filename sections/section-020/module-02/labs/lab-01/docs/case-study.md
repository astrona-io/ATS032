---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Starting Environment

The `starfleet-032-020-02-01` namespace runs the Deployment `probe` (two replicas) and the pod `shuttle`. Both use the `default` ServiceAccount. Someone fixed an old error by creating the Role `pod-access` and binding it to the `default` ServiceAccount of `starfleet-032-020-02-01` with the RoleBinding `default-pod-access`, so every pod of the namespace can read pods. The `outpost-032-020-02-01` namespace runs the pod `drifter`.

Move one workload to a dedicated ServiceAccount without a token, create a ServiceAccount that has one narrow grant, and remove the grant from the default account.
