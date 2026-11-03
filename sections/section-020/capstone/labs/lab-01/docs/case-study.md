---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Starting Environment

The `starfleet` namespace runs the Deployment `probe` (two replicas) and the pod `shuttle`. Both use the `default` ServiceAccount, and the RoleBinding `default-pod-access` gives that account the Role `pod-access`, which reads pods. The `shuttle` pod must read pods in its own namespace. The `outpost` namespace runs the pod `drifter`, which never calls the API. The Secret `drifter-legacy-token` is a long-lived token, and the ClusterRoleBinding `outpost-view-all` gives the `view` ClusterRole to every ServiceAccount of `outpost` in all namespaces.

Give each workload its own identity, remove the grants and tokens that a review found, and prove the result with allowed and denied permission checks.
