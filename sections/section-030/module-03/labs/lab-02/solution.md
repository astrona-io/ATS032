---
draft: true
---
# Solution

Update the existing registration:

```sh
kubectl patch validatingwebhookconfiguration training-guard --type=json -p '[{"op": "replace", "path": "/webhooks/0/failurePolicy", "value": "Fail"}, {"op": "replace", "path": "/webhooks/0/namespaceSelector", "value": {"matchLabels": {"admission.training/protected": "true"}}}, {"op": "replace", "path": "/webhooks/0/timeoutSeconds", "value": 2}]'
```

Use the preparation lesson's server-side probes to check healthy decisions and the outage. Restore `guard` to one replica and wait for rollout completion.
