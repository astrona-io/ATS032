# Disable Unneeded ServiceAccount Tokens: Solution

The Pod `no-token-reader` runs as the `default` ServiceAccount, so the kubelet mounts an API token into its container. The fix has two layers. A new ServiceAccount turns token mounting off for every Pod that uses it, and the Pod spec turns it off again, so the Pod stays safe even if someone changes the ServiceAccount later.

## Step 1: Look at the starting Pod

First connect to the lab cluster:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-020-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-020-01-01" || exit 1
```

Check which ServiceAccount the Pod uses and list the token directory inside its container:

```sh
kubectl -n starfleet-032-020-01-01 get pod no-token-reader -o jsonpath='{.spec.serviceAccountName}{"\n"}'
kubectl -n starfleet-032-020-01-01 exec no-token-reader -- ls /var/run/secrets/kubernetes.io/serviceaccount
```

```text
default
ca.crt
namespace
token
```

The file `token` is a ServiceAccount token. Any process in the container can read it and send it to the API server.

## Step 2: Create the ServiceAccount without token mounting

A ServiceAccount is a Kubernetes identity for processes that run in Pods. The field `automountServiceAccountToken: false` tells the ServiceAccount admission controller in the API server not to add a token volume to Pods that use this ServiceAccount.

Save this as `serviceaccount-no-api.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: no-api
  namespace: starfleet-032-020-01-01
automountServiceAccountToken: false
```

Apply it:

```sh
kubectl apply -f serviceaccount-no-api.yaml
```

```text
serviceaccount/no-api created
```

Then check the result. The field must be `false`, and the ServiceAccount must have only the permissions that every ServiceAccount gets:

```sh
kubectl -n starfleet-032-020-01-01 get serviceaccount no-api -o jsonpath='{.automountServiceAccountToken}{"\n"}'
kubectl auth can-i --list -n starfleet-032-020-01-01 --as=system:serviceaccount:starfleet-032-020-01-01:no-api
```

```text
false
Resources                                       Non-Resource URLs                      Resource Names   Verbs
selfsubjectreviews.authentication.k8s.io        []                                     []               [create]
selfsubjectaccessreviews.authorization.k8s.io   []                                     []               [create]
selfsubjectrulesreviews.authorization.k8s.io    []                                     []               [create]
                                                [/.well-known/openid-configuration/]   []               [get]
                                                [/.well-known/openid-configuration]    []               [get]
                                                [/api/*]                               []               [get]
...
```

The output is shortened. The three `create` rules and the `get` rules on URLs such as `/api` and `/healthz` come from default ClusterRoles that bind to every authenticated user. They let a client ask what it may do and read discovery data; they give no access to Pods, Secrets or other objects. Do not create a Role or binding for `no-api`.

## Step 3: Recreate the Pod as no-api

Kubernetes does not let you change `serviceAccountName` on a running Pod, so delete the Pod and create it again. Setting `automountServiceAccountToken: false` in the Pod spec as well protects the Pod on its own: the Pod field wins over the ServiceAccount field.

```sh
kubectl -n starfleet-032-020-01-01 delete pod no-token-reader
```

```text
pod "no-token-reader" deleted from starfleet-032-020-01-01 namespace
```

Save this as `pod-no-token-reader.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-token-reader
  namespace: starfleet-032-020-01-01
  labels:
    app: no-token-reader
spec:
  serviceAccountName: no-api
  automountServiceAccountToken: false
  restartPolicy: Never
  containers:
  - name: reader
    image: docker.io/library/busybox:1.37.0
    command: ["sh", "-c", "sleep 86400"]
```

Apply it:

```sh
kubectl apply -f pod-no-token-reader.yaml
```

```text
pod/no-token-reader created
```

## Step 4: Check that the container has no token

Wait for the Pod, then list the token directory again:

```sh
kubectl -n starfleet-032-020-01-01 wait --for=condition=Ready pod/no-token-reader --timeout=90s
kubectl -n starfleet-032-020-01-01 exec no-token-reader -- ls /var/run/secrets/kubernetes.io/serviceaccount
```

```text
pod/no-token-reader condition met
ls: /var/run/secrets/kubernetes.io/serviceaccount: No such file or directory
command terminated with exit code 1
```

The error is the result you want. The Pod has no token volume, so the kubelet mounted no token, and a process in this container has no credential to send to the API server.

Finally confirm both fields on the Pod:

```sh
kubectl -n starfleet-032-020-01-01 get pod no-token-reader -o jsonpath='{.spec.serviceAccountName} {.spec.automountServiceAccountToken}{"\n"}'
```

```text
no-api false
```
