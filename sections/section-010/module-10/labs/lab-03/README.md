# Revoke An Action That Several Bindings Grant (author notes)

Graded lab `ats-032-lab-010-01-03`. The learner task is `question.md` and the walkthrough is `solution.md`.

- Start in `outpost-032-010-01-03`: `shuttle-configmap-reader` (keep), and three Pod-read grants for `shuttle`: `shuttle-view` (ClusterRole `view`, ServiceAccount subject), `shuttle-pod-lister` (Role `pod-lister`, User `system:serviceaccount:starfleet-032-010-01-03:shuttle`) and `starfleet-workloads` (Role `pod-lister`, Group `system:serviceaccounts:starfleet-032-010-01-03`).
- Guard (runs with every outcome): `shuttle-configmap-reader` still references `configmap-reader`, the Role still allows exactly ConfigMap `get`, `list`, and `shuttle` can list ConfigMaps.
- Outcomes (one point each):
  - `pod-read-revoked`: `kubectl auth can-i` says `no` for `get`, `list`, `watch` Pods as `shuttle`.
  - `only-configmap-read`: the rules review of `shuttle` in outpost, minus a baseline ServiceAccount, equals ConfigMap `get`, `list`.
- Any fix that reaches this state passes, for example editing roles instead of deleting bindings.
- `testing/check.py`, `testing/verify-start.sh`, `testing/wait-solved.sh` and the `validation/` wrappers are copies of `scripts/ci/lab-files/`; do not edit them here.
