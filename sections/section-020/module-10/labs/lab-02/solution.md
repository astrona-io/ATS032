# Replace a Legacy Token Secret With a Projected Token: Solution

A Secret of type `kubernetes.io/service-account-token` holds a long-lived ServiceAccount token. The token has no expiry time and no audience, so anyone who copies it can call the API server until someone deletes the Secret. A projected ServiceAccount token is different: the kubelet asks the API server for it through the TokenRequest API, it expires, the kubelet renews it, and it is valid only for the audience written in the Pod spec.

## Step 1: Look at the starting state

First connect to the lab cluster:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-020-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-020-01-02" || exit 1
```

List the Secret, the volumes of the Pod and the token files in its container:

```sh
kubectl -n outpost-032-020-01-02 get secret reporter-legacy-token
kubectl -n outpost-032-020-01-02 get pod ledger-client -o jsonpath='{.spec.volumes[*].name}{"\n"}'
kubectl -n outpost-032-020-01-02 exec ledger-client -- ls /var/run/tokens /var/run/secrets/kubernetes.io/serviceaccount
```

```text
NAME                    TYPE                                  DATA   AGE
reporter-legacy-token   kubernetes.io/service-account-token   3      12s
ledger-token kube-api-access-sdbz7
/var/run/secrets/kubernetes.io/serviceaccount:
ca.crt
namespace
token

/var/run/tokens:
ledger-token
```

The Pod has two tokens. The volume `ledger-token` holds the long-lived token from the Secret. The volume `kube-api-access-sdbz7` is the default token that the kubelet mounts because token mounting is on. The suffix of that volume name is random and differs in your cluster.

## Step 2: Recreate the Pod with a projected token

Kubernetes does not let you change the volumes of a running Pod, so delete it first:

```sh
kubectl -n outpost-032-020-01-02 delete pod ledger-client
```

```text
pod "ledger-client" deleted from outpost-032-020-01-02 namespace
```

The new Pod uses a `projected` volume with a `serviceAccountToken` source. The field `audience` sets the `aud` claim of the token, `expirationSeconds` sets its lifetime (600 is the smallest value the API server accepts), and `path` sets the file name inside the mount. `automountServiceAccountToken: false` removes the default token.

Save this as `pod-ledger-client.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ledger-client
  namespace: outpost-032-020-01-02
  labels:
    app: ledger-client
spec:
  serviceAccountName: reporter
  automountServiceAccountToken: false
  restartPolicy: Never
  containers:
  - name: client
    image: docker.io/library/busybox:1.37.0
    command: ["sh", "-c", "sleep 86400"]
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

```text
pod/ledger-client created
```

Then check the result. The token file must exist, and the default token directory must be gone:

```sh
kubectl -n outpost-032-020-01-02 wait --for=condition=Ready pod/ledger-client --timeout=90s
kubectl -n outpost-032-020-01-02 exec ledger-client -- ls -l /var/run/tokens/
kubectl -n outpost-032-020-01-02 exec ledger-client -- ls /var/run/secrets/kubernetes.io/serviceaccount
```

```text
pod/ledger-client condition met
total 0
lrwxrwxrwx    1 root     root            19 Nov 17 21:28 ledger-token -> ..data/ledger-token
ls: /var/run/secrets/kubernetes.io/serviceaccount: No such file or directory
command terminated with exit code 1
```

The file is a link into `..data`. The kubelet writes each renewed token to a new folder and moves the link, so the application always reads a valid token.

## Step 3: Read the claims of the new token

A ServiceAccount token is a JSON Web Token (JWT): three base64url parts joined by dots. The middle part holds the claims. This command decodes only that part and does not print the token itself:

```sh
kubectl -n outpost-032-020-01-02 exec ledger-client -- cat /var/run/tokens/ledger-token | cut -d. -f2 | tr '_-' '/+' | base64 -d 2>/dev/null; echo
```

```text
{"aud":["ledger"],"exp":1794951535,"iat":1794950935,"iss":"https://kubernetes.default.svc.cluster.local","jti":"a6a52953-6b6d-4b02-98f8-e08344c2c9f2","kubernetes.io":{"namespace":"outpost-032-020-01-02","node":{"name":"astro-ats-032-lab-020-01-02-worker","uid":"a3d33394-755f-49fe-9954-99bef09572c7"},"pod":{"name":"ledger-client","uid":"6743d7c8-6f94-41b8-bb32-1ddc87dc4d3d"},"serviceaccount":{"name":"reporter","uid":"68a3868b-ac30-4f54-b481-4e877cde118c"}},"nbf":1794950935,"sub":"system:serviceaccount:outpost-032-020-01-02:reporter"
```

The `aud` claim is `ledger`, and `exp` minus `iat` is 600 seconds. The token is also bound to this Pod: when the Pod is deleted, the API server stops accepting the token. The closing brace can be missing in the output, because `base64 -d` stops at the missing padding. Your values differ.

## Step 4: Delete the long-lived Secret

No Pod uses the Secret any more, so delete it and check that no long-lived token Secret is left:

```sh
kubectl -n outpost-032-020-01-02 delete secret reporter-legacy-token
kubectl -n outpost-032-020-01-02 get secrets --field-selector type=kubernetes.io/service-account-token
```

```text
secret "reporter-legacy-token" deleted from outpost-032-020-01-02 namespace
No resources found in outpost-032-020-01-02 namespace.
```

Deleting the Secret is what makes the old token useless. The token controller in the kube-controller-manager created that token from the Secret, and the API server accepts it only while the Secret exists.
