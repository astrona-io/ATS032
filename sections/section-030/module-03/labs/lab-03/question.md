---
exam_objectives:
- Restrict access to Kubernetes API
---
# Make An Admission Webhook Fail Closed Safely

Allow about 8 minutes for the tasks.

The ValidatingWebhookConfiguration `image-review` sends every new Pod with the label `review: image` to an image review service. The webhook `image-review.astrona.io` is set to fail open, waits up to 30 seconds for an answer and matches Pods in every namespace, including `kube-system`. The service it calls is not running, so right now the rule silently does nothing.

## Connect to the lab

Use a shell on your own machine. The kubeconfig file holds the address and the credentials of this lab's cluster, and `kubectl` uses it.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-030-03-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-030-03-03" || exit 1
```

## Tasks

Change the webhook `image-review.astrona.io` in the ValidatingWebhookConfiguration `image-review`:

1. Make a failed call reject the request: set `failurePolicy` to `Fail`.
2. Set `timeoutSeconds` to 10 or less.
3. Add a `namespaceSelector` that excludes the namespace `kube-system` and still selects `starfleet-032-030-03-03`.

Keep the name of the webhook, its rules for Pod `CREATE` requests, its `objectSelector` and its `clientConfig`. Do not create the webhook service. After the change, a Pod with the label `review: image` in `starfleet-032-030-03-03` must be rejected because the webhook cannot be called. The same Pod in `kube-system` must be admitted.
