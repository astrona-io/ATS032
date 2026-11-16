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
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-020-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-020-03" || exit 1
kubectl get secrets -A --field-selector type=kubernetes.io/service-account-token
kubectl get secrets -A --field-selector type=kubernetes.io/service-account-token -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,SERVICEACCOUNT:'.metadata.annotations.kubernetes\.io/service-account\.name'
```

The playground has one such Secret, `ledger-legacy-token` in `outpost`, and the second command shows that it belongs to `ledger`. A Secret of this type is a finding unless a documented system needs it. The usual replacement is a token with a lifetime, created for the moment it is needed. Delete the Secret when nothing uses it:

```sh
kubectl -n outpost delete secret ledger-legacy-token
```

## Find projected tokens with long lifetimes

The Pod's `expirationSeconds` requests a token lifetime. The API default for an explicit projection is 3600 seconds; this cluster's automatically injected volume requests 3607. The server determines the issued expiration. The Pod `ledger-client` requests 86400 seconds. Print the requested values across the cluster; a Pod without a token projection has no value:

```sh
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{"\t"}{.spec.volumes[*].projected.sources[*].serviceAccountToken.expirationSeconds}{"\n"}{end}'
```

The `outpost/ledger-client` line shows a request for one day. Treat it as a review finding, then inspect the issued token's expiry to establish its actual lifetime. Kubelet refreshes projected tokens before expiry; rotation does not itself revoke an already copied token. The minimum requested duration is 600 seconds. See the [Kubernetes projected-token documentation](https://kubernetes.io/docs/concepts/storage/projected-volumes/#serviceaccounttoken-projected-volumes) for the API contract.

## Request a token and test it against the API server

A TokenRequest asks the API server for a token with an audience and a lifetime. To test that token, remove your administrator credentials from the client configuration. Adding `--token` to a kubeconfig that still contains a client certificate can authenticate through that certificate and invalidate the experiment.

Using the selected playground context, save its server address and public certificate authority (CA). The CA verifies the API server; it does not authenticate you:

```sh
api_server=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
ca_file=$(mktemp)
kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > "$ca_file"
```

Request a token for `archive`, then send it using an empty kubeconfig. Only the explicit token authenticates this request:

```sh
token=$(kubectl -n outpost create token archive --duration=10m)
kubectl --kubeconfig=/dev/null --server="$api_server" --certificate-authority="$ca_file" --token="$token" auth whoami
```

The response must identify `system:serviceaccount:outpost:archive`. A response naming your administrator means the test has not isolated the token. Now request the same identity with an audience that this API server does not accept:

```sh
token=$(kubectl -n outpost create token archive --audience=ledger --duration=10m)
kubectl --kubeconfig=/dev/null --server="$api_server" --certificate-authority="$ca_file" --token="$token" auth whoami
unset token
rm "$ca_file"
```

The request should fail as unauthorized. The token is intended for `ledger`, not this API server. Treat the requested duration as a request: the server can choose a different expiration. Inspect the issued token's claims locally if you need its actual expiry, without recording the credential in a report.

## Repair an explicit projection

Disabling the default mount does not remove a token volume explicitly declared by the Pod. For a workload that needs one API token, use `automountServiceAccountToken: false` and an explicit projection. This fragment belongs inside a Pod's `spec`:

```yaml
automountServiceAccountToken: false
volumes:
- name: ledger-token
  projected:
    sources:
    - serviceAccountToken:
        path: token
        expirationSeconds: 3600
```

Mount `ledger-token` read-only in the container that needs it. A volume entry alone does not expose the file to a container. Omitting `audience` requests the API server's default audience; use an explicit audience when the receiving service requires another one. Pod volume sources cannot normally be changed in place, so export the manifest, remove server-generated fields, recreate the Pod with the corrected projection and wait for readiness. Then inspect both the live volume and the mounted path. This checks the configuration applied to the workload, while the isolated request above checks token acceptance.

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
