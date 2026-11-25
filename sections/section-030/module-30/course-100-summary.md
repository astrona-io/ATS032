# Summary

Admission is the third check of the Kubernetes API server. It runs after authentication and authorization, when the caller is known and allowed. It is the only check that reads the content of a write request.

Admission applies to every caller, including `cluster-admin`. It sees create, update and delete requests, and it can reject them or change the object. Authorization decides who may do what. Admission decides whether the object itself is acceptable.

Pod Security admission is built into the API server. The Pod Security Standards have three levels: privileged, baseline and restricted. Labels on a namespace set a level for each of the modes `enforce`, `audit` and `warn`, and only `enforce` rejects a Pod. A label does not remove Pods that already exist. When a Deployment creates a Pod that breaks the rule, the error appears in the events of its ReplicaSet. A `warn` label at a stricter level shows what a future change would break.

A ValidatingAdmissionPolicy keeps a rule inside the API server as a Common Expression Language (CEL) expression. The policy matches requests and holds the expressions. The binding switches the policy on, selects where it applies and chooses the actions `Deny`, `Warn` or `Audit`. A new rule should start without `Deny`. A policy cannot change objects or call outside services, but it also cannot be down.

An admission webhook is an HTTPS service that the API server calls. A mutating webhook can change the object, and a validating webhook can only accept or reject it. Mutating webhooks run before the validators, so a validator sees the changed object. The `failurePolicy` decides what a failed call means: `Fail` rejects the request, and `Ignore` lets it through. For a security rule, `Ignore` is a bypass whenever the service is down. Selectors keep a webhook away from its own namespace and from `kube-system`, so a broken webhook cannot block its own recovery.

Key facts to remember:

- Admission runs after authorization and applies to `cluster-admin` too.
- Only the `enforce` mode of Pod Security admission rejects a Pod.
- A ValidatingAdmissionPolicy does nothing until a binding selects the request.
- Match `UPDATE` as well as `CREATE`, or a user can change an object into a forbidden one.
- `failurePolicy: Fail` fails closed; `failurePolicy: Ignore` fails open.

Clean up the playground when you finish.

<!-- astrona:playground:destroy -->
