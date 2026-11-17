# Restart The Container Runtime On A Drained Worker

Author notes for the graded lab `ats-032-lab-040-03-02`. The learner reads `question.md` and,
after the attempt, `solution.md`.

- `bootstrap/setup.sh` cordons the control plane while the Deployment `probe`
  starts, so both Pods land on the worker. It then records the `containerd`
  `ActiveEnterTimestampMonotonic` of the worker and the probe Pod UIDs in the
  ConfigMap `maintenance-baseline`, and cordons the worker.
- `testing/live.py` compares the live values with that baseline:
  `runtime-restarted` reads `systemctl show containerd` through `node_exec()`,
  `probe-pods-replaced` checks that no baseline UID remains and two replicas
  are available, and `worker-in-service` checks Ready and schedulable.
- `solution/apply.sh` drains the worker, restarts `containerd` in the worker
  container, waits for Ready and uncordons.
- The lab runs a command inside a node container, so its `examScope` is
  `cluster`.

Run `astrona validate .` and `astrona test . --accept-terms --headless` in this
folder. `testing/verify-start.sh` checks that every outcome fails on the
starting state; after the reference solution every outcome must pass.
