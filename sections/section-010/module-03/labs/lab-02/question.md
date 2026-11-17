---
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Fix The Subjects Of A RoleBinding

Allow about 6 minutes for the tasks.

This lab runs in its own kind cluster. Connect to it first:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-010-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-010-03-02" || exit 1
```

The RoleBinding `observers` in `outpost-032-010-03-02` should give the ClusterRole `view` to three subjects, but none of them can list Pods there. The binding was written by hand, and its subject list has mistakes.

Change only the subjects of `observers`. Keep its name, its namespace and its role, the ClusterRole `view`.

1. The only User subject must be `jane`, written exactly like this.
2. The only Group subject must be `outpost-observers`.
3. The only ServiceAccount subject must be the ServiceAccount `probe` of the namespace `starfleet-032-010-03-02`.

After the change, each of the three subjects must be able to list Pods in `outpost-032-010-03-02`, and the names that the binding names today must not.
