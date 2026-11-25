# Summary

A review of ServiceAccounts across a cluster answers three questions: which pods run as which account, who can act as each account, and which tokens exist.

The first answer comes from the pod and ServiceAccount objects. A pod holds a token when its own automount field is true, or when that field is empty and the account field is empty or true. A pod can also hold a token in a projected volume of its own. An empty field means that the other object decides. The container is the final proof: look for the token directory, and never print the token.

The second answer comes from bindings. A binding reaches an account by naming it or by naming a group. Kubernetes places every account in `system:serviceaccounts` and in `system:serviceaccounts:<namespace>`. So one binding to a group grants a Role to every account in scope, whatever its mount setting. A ClusterRoleBinding applies in all namespaces.

The API server combines all bindings, so `kubectl auth can-i --list --as` gives the effective permissions of an account. Rights to read Secrets deserve your attention first, because Secrets hold other credentials.

The third answer comes from tokens. A Secret of type `kubernetes.io/service-account-token` has no expiry, and a field selector on the type finds these Secrets in all namespaces. The annotation `kubernetes.io/service-account.name` names the account of each one. A projected token with a long `expirationSeconds` is a long-lived credential as well, and the minimum lifetime is 600 seconds.

The API server accepts only tokens that name its own audience, so it refuses a token for another audience with `Unauthorized`. You can test this without showing the token: create it with `kubectl create token` and store it as a separate kubeconfig user with `kubectl config set-credentials`.

The findings have standard fixes. Remove bindings that give broad Roles to workloads or to ServiceAccount groups, and bind narrow Roles to the accounts that need them. Delete unused token Secrets, and recreate pods with short token lifetimes.

Key facts to remember:

- `<none>` in an automount column means not set, not disabled.
- Group bindings reach accounts that have token mounting turned off.
- Legacy token Secrets are listed with `--field-selector type=kubernetes.io/service-account-token`.
- The API server refuses tokens for other audiences.
- Pass tokens with `$(...)` so they never appear on the screen.

<!-- astrona:playground:destroy -->
