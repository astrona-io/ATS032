---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Admission Control For API Writes

A request can have a known caller and an allowed verb and still be harmful. A user who may create Pods can create a Pod that mounts the host file system. Authorization cannot see that, because it looks at who and what and never at the content. Admission control is the third check of the API server, and it is the only one that reads the object that a write request carries. This module shows the three ways to enforce rules at that point.

Keep one sentence in mind for this module: **admission runs after authorization, applies to every caller including `cluster-admin`, and rejects or changes the content of a write.** You will turn on the built-in Pod Security admission for a namespace, write a rule in the Common Expression Language (CEL) as a ValidatingAdmissionPolicy, and see what an admission webhook does when its service is down.

The module has three parts. **Pod Security Admission** enforces the Pod Security Standards with namespace labels. **ValidatingAdmissionPolicy With CEL** writes a custom rule that runs inside the API server. **Admission Webhooks And Failure Policy** covers calls to an external service and the setting that decides what happens when the call fails.

## Learning objectives

After this module you can:

- Say where admission sits in the request path, which requests it sees and why `cluster-admin` is not exempt.
- Name the three Pod Security Standards and the three modes, and set them with namespace labels.
- Write a ValidatingAdmissionPolicy with a CEL expression and a binding that limits it to a namespace.
- Choose between the validation actions `Deny`, `Warn` and `Audit`.
- Explain `failurePolicy`, the selectors of a webhook and the risk of a rule that fails open.

## Before you start

You need Kubernetes basics: Pods, Services, ConfigMaps, namespaces and labels. Knowing that RBAC authorizes a request before admission helps.

The commands run against a playground cluster. Your terminal must use the playground's private kubeconfig, the file that holds the cluster address and credentials for `kubectl`. Run these two commands once in every new terminal:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-030-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-030-03" || exit 1
```

The playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and one worker node. Your own credentials have the `cluster-admin` role, and admission applies to them as well. The cluster starts with this content:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The Deployment `probe` with two replicas, the Service `probe` and the pod `shuttle` |
| `outpost` | The pod `drifter`, a client with BusyBox tools. No admission rule applies to this namespace yet |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

## Independent live assessment

Prepare with [Test A Webhook During An Outage](course-03a-test-webhook-outages.md). [Bound A Webhook Outage](labs/lab-02/question.md) uses its own kind environment. The healthy webhook rejects restricted ConfigMaps only in the protected namespace; The protected namespace fails closed during a webhook outage while other namespaces remain usable.
