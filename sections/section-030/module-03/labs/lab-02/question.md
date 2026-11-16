---
draft: true
---
# Bound A Webhook Outage

Solve this question on: `terminal`

The running TLS webhook `guard` rejects ConfigMaps labeled `restricted=true`. Its registration currently selects no namespace and ignores endpoint failures.

Allow 10–15 minutes for task work. Cluster startup adds time.

## Tasks

1. Repair `training-guard`: select only namespaces labeled `admission.training/protected=true`, set `failurePolicy: Fail` and `timeoutSeconds: 2`. Preserve the CA, endpoint, rules and webhook implementation.
2. Verify that ordinary ConfigMaps are accepted in `protected`, restricted ones are denied, and `ordinary` remains outside the policy. Scale the webhook Deployment to zero and prove protected requests fail while ordinary requests succeed; restore its single replica.

## Constraints

Keep the namespace labels, TLS Secret and server unchanged. Use server-side dry runs for probes. Leave the webhook healthy when finished.

## How the answer is checked

Fresh API requests test allowed and denied decisions. The grader briefly removes webhook endpoints, verifies the failure response and restores the Deployment even if a check fails.
