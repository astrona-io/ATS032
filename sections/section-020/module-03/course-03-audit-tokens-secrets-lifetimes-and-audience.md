---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Audit Tokens: Secrets, Lifetimes And Audience

A token is a credential, and a review has to find every credential. Kubernetes has two kinds that last a long time. The first is a Secret of type `kubernetes.io/service-account-token`, which never expires. The second is a projected token that a pod requests with a very long lifetime. This part lists both, matches each Secret to its ServiceAccount, and then uses the TokenRequest API to show that the API server accepts a token only for its own audience.

## Find the legacy token Secrets

A Secret of type `kubernetes.io/service-account-token` holds a JSON Web Token (JWT) that the token controller creates for the ServiceAccount named in the annotation `kubernetes.io/service-account.name`. It has no expiry and no binding to a pod. Anyone who reads it can act as the account until the Secret or the account is deleted. The field selector `type` finds these Secrets across the cluster. The custom columns add the account from the annotation. The backslash before each dot is needed because the annotation key itself contains dots.

<!-- astrona:playground:renew -->

```sh
kubectl get secrets -A --field-selector type=kubernetes.io/service-account-token
kubectl get secrets -A --field-selector type=kubernetes.io/service-account-token -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,SERVICEACCOUNT:'.metadata.annotations.kubernetes\.io/service-account\.name'
```

The playground has one such Secret, `ledger-legacy-token` in `outpost`, and the second command shows that it belongs to `ledger`. A Secret of this type is a finding unless a documented system needs it. The usual replacement is a token with a lifetime, created for the moment it is needed. Delete the Secret when nothing uses it:

```sh
kubectl -n outpost delete secret ledger-legacy-token
```

## Find projected tokens with long lifetimes

A projected token has a lifetime that the pod author chooses in `expirationSeconds`. The default is 3607 seconds, a little over an hour. A pod can ask for much more, and the API server accepts it. The pod `ledger-client` asks for 86400 seconds. To find such pods across the cluster, print the lifetime of each projected token. A pod without an explicit volume prints the default.

```sh
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{"\t"}{.spec.volumes[*].projected.sources[*].serviceAccountToken.expirationSeconds}{"\n"}{end}'
```

Pods that use the default mount show 3607. The line for `outpost/ledger-client` shows 86400, which is more than a day. A long lifetime is a finding because a stolen token stays useful for that long, and the kubelet only refreshes the file at about 80 percent of the lifetime. Short lifetimes limit the damage, and the minimum the API accepts is 600 seconds.

## Request a token and test it against the API server

You can request a token yourself and use it. The command `kubectl create token` calls the TokenRequest API and prints the JWT. The option `--token` makes `kubectl` send a given token instead of your own credentials. Put the first command inside `$(...)` so the token goes straight into the second command and never appears on the screen. `kubectl auth whoami` prints the identity that the API server sees.

```sh
kubectl --token="$(kubectl -n outpost create token archive)" auth whoami
kubectl --token="$(kubectl -n outpost create token archive --audience=ledger)" auth whoami
```

The first command prints the user name `system:serviceaccount:outpost:archive` together with its groups. The second fails with an `Unauthorized` error. The token is valid, but its audience is `ledger`, and the API server accepts only tokens that name its own audience. This is the property you use when a workload needs a token for another service: the token is useless against the API server.

The same call shows the effect of the lifetime. Ask for the shortest token and test it:

```sh
kubectl --token="$(kubectl -n outpost create token archive --duration=10m)" auth can-i list pods -n outpost
```

The answer is `yes`, because of the group binding found earlier. Ten minutes after the token was created, the same call is refused. Tokens from `kubectl create token` can also be tied to an object with `--bound-object-kind` and `--bound-object-name`, and then they stop working as soon as that pod or Secret is deleted.

## What to record in a review

An audit has to end with a list that someone can act on. For each ServiceAccount, record the pods that use it, the effective permissions, the long-lived Secrets and the projected tokens with long lifetimes. Order the list by the size of the permissions, not by the number of findings. A token that can read Secrets in a namespace is a higher priority than ten tokens that can read nothing.

You now know how to find long-lived credentials, how to match them to accounts and how to test tokens without exposing them. You also have the whole audit: the inventory of pods and accounts, the bindings and effective permissions, and the tokens. Fixing the findings follows the same rules as before: remove what is not needed, narrow what is, and shorten what lives too long.

## Common pitfalls

> [!WARNING]
> - **Printing a token to the screen or to a ticket.** Use `$(...)` to pass it to the next command.
> - **Forgetting the backslashes in the annotation column.** The key contains dots, and `custom-columns` reads dots as path separators.
> - **Deleting a token Secret that a system still uses.** Check which workload reads it before you delete it.
> - **Rating only the Secrets.** A projected token with a 24-hour lifetime is also a long-lived credential.
> - **Testing a token only against your own audience.** Test that a token meant for another service is refused by the API server.
