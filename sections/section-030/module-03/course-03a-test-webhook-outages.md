---
draft: true
---
# Test A Webhook During An Outage

A validating webhook can explicitly reject an object while healthy. Its failure policy answers a different question: what should the API server do when it cannot obtain a valid response? `Fail` rejects the affected API request; `Ignore` lets it continue through admission. This independent lab uses a small TLS server that rejects ConfigMaps labeled `restricted=true`.

<!-- astrona:playground:renew -->

Inspect the registration and the serving Deployment:

```sh
kubectl get validatingwebhookconfiguration training-guard -o yaml
kubectl -n webhook-system get deployment guard
kubectl get namespaces --show-labels
```

Edit the existing registration with `kubectl edit validatingwebhookconfiguration training-guard`. Set these fields on its single webhook while preserving `clientConfig`, `rules`, `sideEffects` and `admissionReviewVersions`:

```yaml
failurePolicy: Fail
timeoutSeconds: 2
namespaceSelector:
  matchLabels:
    admission.training/protected: "true"
```

The namespace selector confines the outage to this policy's workloads. It also keeps the webhook's own namespace outside the policy, so recovering the server does not depend on that server admitting its replacement. A short timeout limits waiting; it does not make an unavailable webhook healthy.

Save a probe as `probe.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: probe
  namespace: protected
  labels:
    restricted: "true"
```

Send the request without persisting the object:

```sh
kubectl create --dry-run=server -f probe.yaml
```

The healthy server should return its explicit policy rejection. Change the label to `false`; the request should succeed. Change the namespace to `ordinary` and restore the restricted label; it should still succeed because that namespace is outside the selector.

Exercise the failure path with an ordinary ConfigMap in `protected`:

```sh
kubectl -n webhook-system scale deployment/guard --replicas=0
kubectl -n webhook-system wait --for=delete pod -l app=guard --timeout=90s
kubectl create --dry-run=server -f probe.yaml
kubectl -n webhook-system scale deployment/guard --replicas=1
kubectl -n webhook-system rollout status deployment/guard --timeout=90s
```

During the outage, expect a failed webhook call, not the server's explicit policy message. Repeat the request in `ordinary` to establish that unrelated namespaces remain usable. Always restore the server before finishing.

## Common pitfalls

> [!WARNING]
> A client-side dry run never reaches admission. Use `--dry-run=server`, and distinguish an explicit policy denial from a TLS, timeout or endpoint failure. An outage test alone cannot prove that a healthy policy makes the right decision.
