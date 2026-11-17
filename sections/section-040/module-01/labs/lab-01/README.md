# Drain A Worker Node With A PodDisruptionBudget

Author notes for the graded lab `ats-032-lab-040-01-01`. The learner reads `question.md` and,
after the attempt, `solution.md`.

- `bootstrap/setup.sh` cordons the control plane while the `probe` Deployment
  starts, so both Pods land on the worker even though they tolerate the control
  plane taint. It then uncordons the control plane and starts the bare Pod
  `drifter` on the worker. The PodDisruptionBudget `probe` starts with
  `minAvailable: 2`, so it allows no disruption.
- `testing/live.py` grades the live state: the `disruptionsAllowed` status of
  every budget that selects `app: probe`, the Pods left on the worker, and
  where `drifter` runs. Any budget shape that allows one disruption passes.
- `solution/apply.sh` is the reference solution that `astrona test` applies.
- The lab drains a node, so its `examScope` is `cluster`.

Run `astrona validate .` and `astrona test . --accept-terms --headless` in this
folder. `testing/verify-start.sh` checks that every outcome fails on the
starting state; after the reference solution every outcome must pass.
