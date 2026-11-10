---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Starting Environment

The `starfleet-032-010-01-01` and `outpost-032-010-01-01` namespaces and `starfleet-032-010-01-01/shuttle` ServiceAccount exist. A ServiceAccount identifies a workload when it calls the Kubernetes application programming interface (API). It has no application-specific Pod read grant.

Create Role `pod-reader` and RoleBinding `shuttle-pod-reader` in `starfleet-032-010-01-01`. Grant ServiceAccount `shuttle` in `starfleet-032-010-01-01` exactly `get`, `list` and `watch` on core Pods. The binding must reference that Role and only that ServiceAccount. Do not add a ClusterRoleBinding or any other grant. Pod creation and deletion, Secret reads, Pod reads in `outpost-032-010-01-01` and node reads must remain denied.
