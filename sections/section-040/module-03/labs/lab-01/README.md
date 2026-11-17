# Verify And Repair A Cluster After Maintenance

Author notes for the graded lab `ats-032-lab-040-03-01`. The learner reads `question.md` and,
after the attempt, `solution.md`.

- `bootstrap/setup.sh` starts the Deployment `probe` (two replicas, required
  anti-affinity on the node name, toleration for the control plane taint) and
  the PodDisruptionBudget `probe` with `minAvailable: 2`. It then cordons the
  worker, adds the taint `maintenance=patching:NoSchedule` and deletes the
  `probe` Pod on the worker, so its replacement stays Pending.
- `testing/live.py`: `worker-in-service` checks both nodes Ready and the worker
  schedulable without a `maintenance` taint; `probe-spread` checks two Ready
  Pods on two nodes; `budget-allows-drain` checks that every budget that
  selects `app=probe` reports `disruptionsAllowed >= 1`, so `maxUnavailable: 1`
  and `minAvailable: 1` both pass.
- `solution/apply.sh` removes the taint, uncordons, waits for the rollout and
  applies `solution/poddisruptionbudget-probe.yaml`.
- The lab changes a node, so its `examScope` is `cluster`.

Run `astrona validate .` and `astrona test . --accept-terms --headless` in this
folder. `testing/verify-start.sh` checks that every outcome fails on the
starting state; after the reference solution every outcome must pass.
