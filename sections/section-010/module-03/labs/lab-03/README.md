# Build An Aggregated ClusterRole (author notes)

Graded lab `ats-032-lab-010-03-03`. The learner task is `question.md` and the walkthrough is `solution.md`.

- Start: namespaces `starfleet-032-010-03-03` and `dock-032-010-03-03`, ServiceAccount `probe` in starfleet, Service `probe-status` in dock. No RBAC objects.
- Outcomes (one point each):
  - `component-roles`: ClusterRoles `fleet-reader-pods` and `fleet-reader-services` carry `fleet.example.com/aggregate-to-fleet-reader: "true"` and their expanded rules equal get/list/watch on Pods and on Services.
  - `aggregated-role`: `fleet-reader` has a non-empty `aggregationRule` and its controller-written rules equal the union of both sets.
  - `probe-binding`: RoleBinding `probe-fleet-reader` in dock references ClusterRole `fleet-reader` and names only starfleet `probe` (ServiceAccount or User form); probe's effective rules (rules review minus the ServiceAccount baseline) equal the union in dock and are empty in starfleet; no ClusterRoleBinding names probe.
- The ClusterRoles are cluster-scoped, so the exam scope is `cluster`. Their names and label key are unique to this lab.
- Tested on the dev cluster: removing the label from `fleet-reader-services` fails all three outcomes.
- `testing/check.py`, `testing/verify-start.sh`, `testing/wait-solved.sh` and the `validation/` wrappers are copies of `scripts/ci/lab-files/`; do not edit them here.
