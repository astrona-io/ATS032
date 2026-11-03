---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Summary

A cluster-wide review of ServiceAccounts answers three questions: which pods run as which account, who can act as each account, and which tokens exist. The first answer comes from the pod and ServiceAccount objects. A pod holds a token when its own automount field is true, or when the field is empty and the account field is empty or true. A pod can also hold a token in a projected volume of its own. An empty field means that the other object decides, and the container is the final proof: look for the token directory, and never print the token.

The second answer comes from bindings. A binding reaches an account by naming it or by naming a group. Kubernetes places every account in `system:serviceaccounts` and in `system:serviceaccounts:<namespace>`, so one binding to a group grants a Role to every account in scope, whatever its mount setting. A ClusterRoleBinding applies in all namespaces. The API server combines all bindings, so `kubectl auth can-i --list --as` gives the effective permissions, and rights to read Secrets deserve the first attention.

The third answer comes from tokens. A Secret of type `kubernetes.io/service-account-token` has no expiry, and a field selector on the type finds it in all namespaces. The annotation `kubernetes.io/service-account.name` names its account. A projected token with a long `expirationSeconds` is a long-lived credential as well, and the minimum lifetime is 600 seconds. The API server accepts only tokens that name its own audience, so a token for another audience is refused with `Unauthorized`. `kubectl create token` and `kubectl --token` test this without exposing the token.

The findings have standard fixes: remove bindings that give broad Roles to workloads or to ServiceAccount groups, bind narrow Roles to the accounts that need them, delete unused token Secrets, and recreate pods with short token lifetimes.

Key facts to remember:

- `<none>` in an automount column means not set, not disabled.
- Group bindings reach accounts that have token mounting turned off.
- Legacy token Secrets are listed with `--field-selector type=kubernetes.io/service-account-token`.
- The API server refuses tokens for other audiences.
- Pass tokens with `$(...)` so they never appear on the screen.

<!-- astrona:playground:destroy -->
