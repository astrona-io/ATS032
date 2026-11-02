---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Bound Tokens, Audience And Legacy Secrets

Some workloads must call the API, or must prove their identity to another service. For them the question changes from "mount or not" to "how long is the credential valid, and who accepts it". Kubernetes answers with bound tokens that expire and name an audience. The older long-lived token stored in a Secret answers neither question, and it is still a finding in many security reviews. This part requests short-lived tokens, configures a projected token with an audience and a lifetime, and looks at the legacy Secret.

## The TokenRequest API

The TokenRequest API is an API call that creates a token for one ServiceAccount, on demand. The API server signs the JSON Web Token (JWT) and returns it. The caller sets how long it should be valid, which objects it is bound to, and which audience it is for. Nothing is stored in the cluster, so there is no Secret to leak from a backup, and the token stops working when it expires.

An **audience** is the party the token is meant for. The `aud` claim in the token lists it. A service that checks a token must verify that its own audience is in the list. The API server accepts a token only when it was issued for the API server's own audience. A token that was issued for the audience `ledger` is therefore useless against the API server, and it is the right form for a pod that proves its identity to a different service.

The kubelet uses this API for the token in every projected volume. You can use it directly with `kubectl create token`. The command below asks for a token for `reporter` that lives ten minutes. It prints the JWT on one line, so run it only in a terminal that nobody else sees, and do not paste the value anywhere. The shortest lifetime the API accepts is ten minutes, and the API server can return a shorter lifetime than you ask for if its own maximum is lower.

<!-- astrona:playground:renew -->

```sh
kubectl -n outpost get serviceaccount reporter || kubectl -n outpost create serviceaccount reporter
kubectl -n outpost create token reporter --duration=10m
```

The first command makes sure that the account exists. The second prints a token. The same command accepts `--audience` to set the audience, and `--bound-object-kind` with `--bound-object-name` to tie the token to a Pod or a Secret, so that it stops working when that object is deleted.

## A projected token with an audience and a lifetime

A pod can ask the kubelet for a token with its own audience and lifetime in a projected volume. The settings are `audience`, `expirationSeconds` and `path` in a `serviceAccountToken` source. The kubelet refreshes the file when about 80 percent of the lifetime has passed. The pod below sets `automountServiceAccountToken: false` so it does not receive the default token, and mounts one token for the audience `ledger` that lives ten minutes.

Save this as `pod-ledger-client.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ledger-client
  namespace: outpost
spec:
  serviceAccountName: reporter
  automountServiceAccountToken: false
  restartPolicy: Never
  containers:
    - name: client
      image: docker.io/library/busybox:1.37.0
      command: ["sh", "-c", "sleep 3600"]
      volumeMounts:
        - name: ledger-token
          mountPath: /var/run/tokens
          readOnly: true
  volumes:
    - name: ledger-token
      projected:
        sources:
          - serviceAccountToken:
              audience: ledger
              expirationSeconds: 600
              path: ledger-token
```

Apply it:

```sh
kubectl apply -f pod-ledger-client.yaml
```

Then check the result:

```sh
kubectl -n outpost wait --for=condition=Ready pod/ledger-client --timeout=90s
kubectl -n outpost exec ledger-client -- ls /var/run/tokens
kubectl -n outpost get pod ledger-client -o jsonpath='{.spec.volumes[0].projected.sources[0].serviceAccountToken}{"\n"}'
```

The `ls` command lists one file, `ledger-token`. The pod has no directory `/var/run/secrets/kubernetes.io/serviceaccount`. The last command prints the token settings as JSON with `audience` set to `ledger`, `expirationSeconds` set to `600` and `path` set to `ledger-token`. This is the form to use whenever a pod must prove its identity to a service other than the API server.

## The legacy token Secret

Before Kubernetes 1.24, the control plane created a Secret for every ServiceAccount. It held a token that never expired. Kubernetes no longer creates these Secrets automatically, but you can still ask for one: a Secret of type `kubernetes.io/service-account-token` with the annotation `kubernetes.io/service-account.name`. The token controller then fills it with a token that is valid as long as the Secret and the ServiceAccount exist. It has no expiry and no audience, and it is not bound to a pod. Anyone who reads the Secret, from a backup or through the API, holds a credential with no end date.

Save this as `secret-reporter-legacy-token.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: reporter-legacy-token
  namespace: outpost
  annotations:
    kubernetes.io/service-account.name: reporter
type: kubernetes.io/service-account-token
```

Apply it:

```sh
kubectl apply -f secret-reporter-legacy-token.yaml
```

Then check the result. The `describe` command shows the keys of a Secret with their sizes and not their values. The second command is the audit that you run on a real cluster: it lists every long-lived token Secret in all namespaces.

```sh
kubectl -n outpost describe secret reporter-legacy-token
kubectl get secrets -A --field-selector type=kubernetes.io/service-account-token
```

The first command lists three keys: `ca.crt`, `namespace` and `token`. The second lists this Secret, and in a real cluster it lists any other legacy tokens that someone created. Remove this one, because nothing needs it:

```sh
kubectl -n outpost delete secret reporter-legacy-token
```

The way to leave a legacy token is the way you learned in this part: ask for a short-lived token with `kubectl create token`, or let the kubelet project one into the pod. Deleting the ServiceAccount also invalidates every token that belongs to it.

You now know that a bound token expires, names an audience and can be tied to a pod, and that the legacy Secret has none of these properties. The checks in this module come together in one rule: the pod gets a credential only when it needs one, the credential is short-lived, and the account behind it has only the permissions the workload uses.

## Common pitfalls

> [!WARNING]
> - **Using the default audience for a token that goes to another service.** That token is valid for the API server. Set `audience` to the receiving service.
> - **Setting `expirationSeconds` below 600.** The API rejects values shorter than ten minutes.
> - **Creating a `kubernetes.io/service-account-token` Secret to get a "permanent" token.** It never expires. Use `kubectl create token` or a projected volume.
> - **Pasting a token into a ticket or chat.** A token is valid until it expires. Treat it as a password.
