---
draft: true
---
# Solution

Save the following as `pod-reporter.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: reporter
  namespace: audience-training
spec:
  serviceAccountName: reporter
  automountServiceAccountToken: false
  containers:
  - name: client
    image: python:3.13-alpine
    command:
    - sleep
    - '36000'
    volumeMounts:
    - name: identity
      mountPath: /identity
      readOnly: true
  volumes:
  - name: identity
    projected:
      sources:
      - serviceAccountToken:
          path: token
          expirationSeconds: 600
          audience: telemetry.training
```

Recreate the Pod:

```sh
kubectl -n audience-training delete pod reporter
kubectl apply -f pod-reporter.yaml
kubectl -n audience-training wait --for=condition=Ready pod/reporter --timeout=180s
```

Verify the intended and incorrect audiences with TokenReview. Use a separate kubeconfig containing only this token to verify direct API rejection.
