# Remove Long-Lived ServiceAccount Tokens: Solution

A token that lives long is a risk, because a copy stays useful for that long. Two kinds of long-lived tokens exist. A Secret of type `kubernetes.io/service-account-token` holds a token with no expiry time at all. A projected token with a large `expirationSeconds` does expire, but only after that many seconds.

## Step 1: Find the long-lived token Secrets

First connect to the lab cluster:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-020-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-020-03-02" || exit 1
```

A field selector on the Secret type finds token Secrets in every namespace. The second command lists all Secrets of the lab namespace with the ServiceAccount named in the annotation `kubernetes.io/service-account.name`:

```sh
kubectl get secrets -A --field-selector type=kubernetes.io/service-account-token
kubectl -n outpost-032-020-03-02 get secrets -o custom-columns='NAME:.metadata.name,TYPE:.type,SERVICEACCOUNT:.metadata.annotations.kubernetes\.io/service-account\.name'
```

```text
NAMESPACE               NAME                  TYPE                                  DATA   AGE
outpost-032-020-03-02   archive-credentials   kubernetes.io/service-account-token   3      6s
outpost-032-020-03-02   ledger-legacy-token   kubernetes.io/service-account-token   3      6s
NAME                  TYPE                                  SERVICEACCOUNT
archive-credentials   kubernetes.io/service-account-token   archive
ledger-legacy-token   kubernetes.io/service-account-token   ledger
ledger-settings       Opaque                                <none>
```

The name `archive-credentials` does not say "token", so a search by name would miss it. The type is what matters. `ledger-settings` is an ordinary Secret of type `Opaque` and holds no token.

## Step 2: Delete the token Secrets

Deleting a token Secret makes its token useless at once, because the API server accepts such a token only while its Secret exists:

```sh
kubectl -n outpost-032-020-03-02 delete secret ledger-legacy-token archive-credentials
kubectl -n outpost-032-020-03-02 get secrets
```

```text
secret "ledger-legacy-token" deleted from outpost-032-020-03-02 namespace
secret "archive-credentials" deleted from outpost-032-020-03-02 namespace
NAME              TYPE     DATA   AGE
ledger-settings   Opaque   1      7s
```

## Step 3: Find projected tokens with a long lifetime

This command prints each Pod with the `expirationSeconds` of its projected tokens:

```sh
kubectl -n outpost-032-020-03-02 get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.volumes[*].projected.sources[*].serviceAccountToken.expirationSeconds}{"\n"}{end}'
```

```text
ledger-client	86400
```

86400 seconds is one day. A Pod that uses the default token mount shows 3607 here; this Pod has only its own projected volume.

## Step 4: Recreate the Pod with a short lifetime

The volumes of a running Pod cannot change, so delete the Pod:

```sh
kubectl -n outpost-032-020-03-02 delete pod ledger-client
```

```text
pod "ledger-client" deleted from outpost-032-020-03-02 namespace
```

Save this as `pod-ledger-client.yaml`. Only `expirationSeconds` differs from the old Pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ledger-client
  namespace: outpost-032-020-03-02
  labels:
    app: ledger-client
spec:
  serviceAccountName: ledger
  automountServiceAccountToken: false
  restartPolicy: Never
  containers:
  - name: client
    image: docker.io/library/busybox:1.37.0
    command: ["sh", "-c", "sleep 86400"]
    volumeMounts:
    - name: api-token
      mountPath: /var/run/tokens
      readOnly: true
  volumes:
  - name: api-token
    projected:
      sources:
      - serviceAccountToken:
          expirationSeconds: 3600
          path: token
```

Apply it:

```sh
kubectl apply -f pod-ledger-client.yaml
```

```text
pod/ledger-client created
```

## Step 5: Check the new token

Wait for the Pod and print the lifetime from the spec again. Then decode only the `exp` (expiry) and `iat` (issued at) claims of the token in the container, without printing the token:

```sh
kubectl -n outpost-032-020-03-02 wait --for=condition=Ready pod/ledger-client --timeout=90s
kubectl -n outpost-032-020-03-02 get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.volumes[*].projected.sources[*].serviceAccountToken.expirationSeconds}{"\n"}{end}'
kubectl -n outpost-032-020-03-02 exec ledger-client -- cat /var/run/tokens/token | cut -d. -f2 | tr '_-' '/+' | base64 -d 2>/dev/null | grep -o '"exp":[0-9]*\|"iat":[0-9]*'
```

```text
pod/ledger-client condition met
ledger-client	3600
"exp":1794955504
"iat":1794951904
```

The difference between `exp` and `iat` is 3600 seconds, so the token is valid for one hour. The kubelet requests a new token before this one expires.

Finally confirm that the API server accepts the token as `ledger`. `kubectl --token` alone would not test it, because the kind kubeconfig also holds a client certificate, which the API server authenticates first. So add the token as a separate kubeconfig user, use it and remove it:

```sh
kubectl config set-credentials ledger-token --token="$(kubectl -n outpost-032-020-03-02 exec ledger-client -- cat /var/run/tokens/token)"
kubectl --user=ledger-token auth whoami
kubectl config delete-user ledger-token
```

```text
User "ledger-token" set.
ATTRIBUTE                                           VALUE
Username                                            system:serviceaccount:outpost-032-020-03-02:ledger
UID                                                 2dd1fbf6-e188-4495-9615-f30d297fb4fd
Groups                                              [system:serviceaccounts system:serviceaccounts:outpost-032-020-03-02 system:authenticated]
Extra: authentication.kubernetes.io/credential-id   [JTI=c1bef454-e135-477e-a5f2-8e1bc697fe44]
Extra: authentication.kubernetes.io/node-name       [astro-ats-032-lab-020-03-02-worker]
Extra: authentication.kubernetes.io/node-uid        [7f7efca0-ff89-44a8-b492-eee279776232]
Extra: authentication.kubernetes.io/pod-name        [ledger-client]
Extra: authentication.kubernetes.io/pod-uid         [cfd5acf3-9026-4ab1-8a7a-304ccc79ed53]
```

The output leaves out the last line, which confirms that `kubectl config delete-user` removed `ledger-token` from your kubeconfig file.
