---
exam_objectives:
- Restrict access to Kubernetes API
---
# Make An Admission Webhook Fail Closed Safely: Solution

Connect to the lab first, so that `kubectl` talks to this lab's cluster:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-030-03-03)"
```

## See the problem

A validating admission webhook is an HTTPS service that the API server calls before it stores an object. The field `failurePolicy` decides what the API server does when the call fails. Send a labelled Pod with a server-side dry run, which goes through admission without storing anything:

```sh
kubectl -n starfleet-032-030-03-03 run test --image=docker.io/library/busybox:1.37.0 --labels=review=image --dry-run=server
```

The command prints `pod/test created (server dry run)`. The API server could not reach the Service `image-review`, and `failurePolicy: Ignore` turned the failed call into an allow. Anyone who can stop the review service can skip the rule.

## Change the webhook

Three fields change. `failurePolicy: Fail` makes a failed call reject the request. A short `timeoutSeconds` limits how long each write waits for a slow service. A `namespaceSelector` keeps `kube-system` out of the rule, so a broken review service cannot block system Pods. The API server sets the label `kubernetes.io/metadata.name` on every namespace, so a `NotIn` expression on that label excludes one namespace by name.

Save this as `validatingwebhookconfiguration-image-review.yaml`:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: image-review
webhooks:
- name: image-review.astrona.io
  admissionReviewVersions: ["v1"]
  sideEffects: None
  failurePolicy: Fail
  timeoutSeconds: 5
  clientConfig:
    service:
      name: image-review
      namespace: starfleet-032-030-03-03
      path: /validate
  rules:
  - apiGroups: [""]
    apiVersions: ["v1"]
    operations: ["CREATE"]
    resources: ["pods"]
  namespaceSelector:
    matchExpressions:
    - key: kubernetes.io/metadata.name
      operator: NotIn
      values: ["kube-system"]
  objectSelector:
    matchLabels:
      review: image
```

Apply it:

```sh
kubectl apply -f validatingwebhookconfiguration-image-review.yaml
```

## Check the result

Send the same labelled Pod to both namespaces:

```sh
kubectl -n starfleet-032-030-03-03 run test --image=docker.io/library/busybox:1.37.0 --labels=review=image --dry-run=server
kubectl -n kube-system run test --image=docker.io/library/busybox:1.37.0 --labels=review=image --dry-run=server
```

The first request fails. The error says that the API server failed calling the webhook `image-review.astrona.io` because the Service `image-review` was not found. The second request prints `pod/test created (server dry run)`, because the namespace selector does not select `kube-system` and the API server makes no call.

## Common pitfalls

> [!WARNING]
> - **Setting `Fail` without a namespace selector.** If the webhook also matches Pods in `kube-system` or in its own namespace, a broken service can block the Pods that the cluster or the webhook itself needs.
> - **Leaving a long timeout.** Every matching write waits up to `timeoutSeconds` when the service hangs. The maximum is 30.
> - **Excluding too much.** A selector that skips `starfleet-032-030-03-03` too makes the rule useless there.
