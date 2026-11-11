---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Summary

This module covered the third check of the Kubernetes API server: admission, which reads the content of a write request after the caller is known and allowed.

Admission applies to every caller, including `cluster-admin`. It sees create, update and delete requests and can reject them or change the object. Authorization decides who does what, and admission decides whether the object is acceptable.

Pod Security admission is built in. The Pod Security Standards have three levels: privileged, baseline and restricted. Namespace labels set the level for each of the modes `enforce`, `audit` and `warn`. A label does not remove Pods that already exist, and a Deployment with a rejected Pod shows the error in the events of its ReplicaSet. Using `warn` at a stricter level shows what a future change would break.

A ValidatingAdmissionPolicy keeps a rule in the API server as a CEL expression. The policy matches requests and holds the expressions, and the binding switches it on, selects the scope and chooses the actions `Deny`, `Warn` or `Audit`. A new rule should start without `Deny`. A policy cannot change objects and cannot call outside services, but it cannot be down either.

An admission webhook calls an HTTPS service and can change or validate the object. Its `failurePolicy` decides what a failed call means: `Fail` rejects the request, and `Ignore` lets it through, which makes a security rule a bypass whenever the service is down. Selectors keep the webhook away from the namespaces it needs to run, and mutating webhooks run before validators.

Clean up the playground when you finish.



## Independent live assessment

Prepare with [Test A Webhook During An Outage](course-03a-test-webhook-outages.md). [Bound A Webhook Outage](labs/lab-02/question.md) uses its own kind environment. The healthy webhook rejects restricted ConfigMaps only in the protected namespace; The protected namespace fails closed during a webhook outage while other namespaces remain usable.

<!-- astrona:playground:destroy -->
