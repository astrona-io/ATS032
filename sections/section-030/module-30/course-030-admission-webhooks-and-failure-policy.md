# Admission Webhooks And Failure Policy

Admission is the step in which the Kubernetes API server reads the object of a write request and can reject or change it. Some admission rules need data from outside the API server, or must change the object. For these rules, the API server calls a webhook. An admission webhook is an HTTPS service that receives the request and answers with a decision.

That call can fail. One setting decides what a failed call means. It makes the difference between a rule that always applies and a rule that disappears whenever its service is down.

## Mutating and validating webhooks

Webhooks come in two kinds. A **mutating** webhook can change the object, for example by adding a sidecar container or a default label. A **validating** webhook can only accept or reject the request.

The two kinds run at different points of the request path. Mutating webhooks run first. Then the API server validates the schema of the object. Then validating admission policies and validating webhooks run. Because the validators run last, they see the object after all changes.

![Diagram: a write request passes authentication, authorization, mutating admission, schema validation, and then validating admission policies and validating webhooks before the API server stores it in etcd](images/admission-request-path.svg)

The drawing shows the order of the steps. A validator always sees the object that a mutating webhook has already changed.

The API server learns about a webhook from a configuration object. Each webhook entry in a `ValidatingWebhookConfiguration` or `MutatingWebhookConfiguration` has the fields that decide its behaviour.

- `rules` lists the operations, API groups and resources that trigger the call.
- `namespaceSelector` and `objectSelector` narrow the calls by namespace labels and object labels.
- `clientConfig` says where to call: a Service in the cluster or a URL, with a CA bundle to verify the server.
- `failurePolicy` is `Fail` or `Ignore` and tells the API server what to do when the call fails or times out.
- `timeoutSeconds` is the time the API server waits, between 1 and 30 seconds.
- `sideEffects` says whether the webhook changes anything outside the request. A value of `None` or `NoneOnDryRun` makes dry-run requests safe.

## Fail closed, fail open

Of all these fields, `failurePolicy` has the biggest effect on security. The two values behave in opposite ways:

- With `failurePolicy: Fail`, a failed call rejects the request. The rule always applies. The cost is that the cluster can no longer create the matching objects while the webhook is down. This is called failing closed.
- With `failurePolicy: Ignore`, a failed call lets the request through. The cluster stays available, but the rule silently stops applying. This is called failing open.

For a security rule, failing open is a bypass. Anyone who can make the service fail, for example by overloading it, can skip the rule.

![Diagram: the API server calls the webhook service; an allow answer admits the request and a deny answer rejects it; a failed call rejects the request under Fail and admits it under Ignore](images/webhook-failure-policy.svg)

The drawing shows that a failed call has the same result as a deny under `Fail`, and the same result as an allow under `Ignore`.

`Fail` has its own risk: a deadlock, where the webhook blocks its own recovery. If the webhook service runs in the same cluster, a `Fail` rule that matches the Pods of the webhook service would block the restart of those Pods. The common fix is to keep the webhook away from the objects it needs to run. Exclude the namespace of the webhook and `kube-system` with a `namespaceSelector`.

## Observe a failed call

You do not need a working webhook to see this behaviour. This configuration points at a Service that does not exist. It matches only ConfigMaps in `outpost` that carry the label `review: required`. Save it as `webhook-require-review.yaml`:

<!-- astrona:playground:renew -->

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: require-review
webhooks:
  - name: require-review.outpost.example
    admissionReviewVersions: ["v1"]
    sideEffects: None
    failurePolicy: Fail
    timeoutSeconds: 5
    clientConfig:
      service:
        name: review-service
        namespace: outpost
        path: /validate
    rules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE"]
        resources: ["configmaps"]
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: outpost
    objectSelector:
      matchLabels:
        review: required
```

Apply it:

```sh
kubectl apply -f webhook-require-review.yaml
```

Now create an object that the webhook matches. Save this ConfigMap as `configmap-reviewed.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: reviewed
  namespace: outpost
  labels:
    review: required
data:
  key: value
```

Apply it:

```sh
kubectl apply -f configmap-reviewed.yaml
```

The request fails. The error says that the API server failed to call the webhook `require-review.outpost.example`, and that the Service `review-service` was not found. The object selector matched the ConfigMap, the API server could not make the call, and `Fail` turned that into a rejection. A ConfigMap without the label does not match the selector, so the API server creates it without any call.

Now change the failure policy of the webhook and apply the ConfigMap again:

```sh
kubectl patch validatingwebhookconfiguration require-review --type=json -p '[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Ignore"}]'
kubectl apply -f configmap-reviewed.yaml
```

This time the API server creates the ConfigMap, although the webhook never answered. With `Ignore`, the API server skipped the rule because the call failed. Remove both objects, so that the broken webhook does not stay in the cluster:

```sh
kubectl delete validatingwebhookconfiguration require-review
kubectl -n outpost delete configmap reviewed
```

## What the API server checks first

Admission is the last check of a write before the API server stores the object. The API server runs admission as a set of plugins, and some built-in plugins are worth knowing here:

- `NodeRestriction` limits what a kubelet, the agent on each node, may change through the API.
- `ValidatingAdmissionPolicy` and the webhook plugins must be enabled for the objects above to work.

These plugins are on by default in a current kubeadm cluster. Read the flag `--enable-admission-plugins` on the API server to see the extra plugins that an administrator switched on.

You now know the three ways to enforce rules on writes: labels for Pod Security, expressions in the API server and external webhooks. Each one has a different cost when it fails. The open question for any new rule is which failure is acceptable, because choosing the setting for a failure is part of the rule itself.

## Common pitfalls

> [!WARNING]
> - **Using `failurePolicy: Ignore` for a security rule.** The rule stops applying whenever the service is down or slow.
> - **Using `Fail` without excluding the namespace of the webhook.** The service cannot restart, and the cluster cannot recover without removing the configuration.
> - **Matching resources in `kube-system`.** A broken webhook can then block system components.
> - **Leaving a test webhook configuration in place.** It keeps rejecting or skipping requests. Delete it after the test.
> - **Forgetting that mutating webhooks run before validators.** A validator sees the changed object, not the one the user sent.
