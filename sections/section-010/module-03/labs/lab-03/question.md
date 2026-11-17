---
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Build An Aggregated ClusterRole

Allow about 10 minutes for the tasks.

This lab runs in its own kind cluster. Connect to it first:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-010-03-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-010-03-03" || exit 1
```

The `probe` workload needs to read Pods and Services in `dock-032-010-03-03`. The team wants one reader role that grows when someone adds a new labelled ClusterRole, without anyone editing the reader role itself. The ServiceAccount `probe` lives in `starfleet-032-010-03-03`. An aggregated ClusterRole is a ClusterRole whose rules the controller manager fills in from every ClusterRole that matches its label selector.

1. Create the ClusterRole `fleet-reader-pods` with `get`, `list` and `watch` on Pods, and the ClusterRole `fleet-reader-services` with `get`, `list` and `watch` on Services. Both resources are in the core API group. Give both ClusterRoles the label `fleet.example.com/aggregate-to-fleet-reader: "true"`.
2. Create the ClusterRole `fleet-reader` with an `aggregationRule` that selects that label. Its rules must end up as exactly the rules of the two ClusterRoles of task 1.
3. In `dock-032-010-03-03`, create the RoleBinding `probe-fleet-reader` that gives the ClusterRole `fleet-reader` to the ServiceAccount `probe` of `starfleet-032-010-03-03` and to no other subject. Do not use a ClusterRoleBinding: `probe` must hold exactly these reads in `dock-032-010-03-03` and nothing in `starfleet-032-010-03-03`.
