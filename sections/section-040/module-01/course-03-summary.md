---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Summary

Cluster lifecycle changes need a known starting state, supported version sequence and controlled workload movement. Cordon and drain have different effects, and disruption budgets constrain selected voluntary actions.

Datastore snapshots protect cluster state rather than every application data source. Recovery must restore suitable identity and topology and then verify useful management and application behavior under the remaining dependencies.

A datastore restore preserves one state boundary and must be coordinated with the other systems the application depends on.
