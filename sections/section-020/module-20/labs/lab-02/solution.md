# Grant a ServiceAccount Least-Privilege Access: Solution

Least privilege means the ServiceAccount gets the permissions its workload uses and nothing more. In Role-Based Access Control (RBAC), a Role lists allowed verbs on resources in one namespace, and a RoleBinding gives that Role to a subject. Because both objects live in `starfleet-032-020-02-02`, the permission cannot reach any other namespace.

## Step 1: Create the ServiceAccount, Role and RoleBinding

First connect to the lab cluster:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-020-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-020-02-02" || exit 1
```

Save this as `serviceaccount-shuttle-reader.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: shuttle-reader
  namespace: starfleet-032-020-02-02
automountServiceAccountToken: false
```

Save this as `role-shuttle-reader.yaml`. The empty string in `apiGroups` is the core API group, where Pods live:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: shuttle-reader
  namespace: starfleet-032-020-02-02
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
```

Save this as `rolebinding-shuttle-reader.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: shuttle-reader
  namespace: starfleet-032-020-02-02
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: shuttle-reader
subjects:
- kind: ServiceAccount
  name: shuttle-reader
  namespace: starfleet-032-020-02-02
```

Apply them:

```sh
kubectl apply -f serviceaccount-shuttle-reader.yaml
kubectl apply -f role-shuttle-reader.yaml
kubectl apply -f rolebinding-shuttle-reader.yaml
```

```text
serviceaccount/shuttle-reader created
role.rbac.authorization.k8s.io/shuttle-reader created
rolebinding.rbac.authorization.k8s.io/shuttle-reader created
```

## Step 2: Ask the API server what the ServiceAccount may do

`kubectl auth can-i` with `--as` asks the API server to evaluate a request as another user. A ServiceAccount has the user name `system:serviceaccount:<namespace>:<name>`. Test the two allowed verbs, a verb that must be refused, another resource and the other namespace:

```sh
kubectl auth can-i list pods -n starfleet-032-020-02-02 --as=system:serviceaccount:starfleet-032-020-02-02:shuttle-reader
kubectl auth can-i get pods -n starfleet-032-020-02-02 --as=system:serviceaccount:starfleet-032-020-02-02:shuttle-reader
kubectl auth can-i delete pods -n starfleet-032-020-02-02 --as=system:serviceaccount:starfleet-032-020-02-02:shuttle-reader
kubectl auth can-i get secrets -n starfleet-032-020-02-02 --as=system:serviceaccount:starfleet-032-020-02-02:shuttle-reader
kubectl auth can-i list pods -n outpost-032-020-02-02 --as=system:serviceaccount:starfleet-032-020-02-02:shuttle-reader
```

```text
yes
yes
no
no
no
```

## Step 3: Recreate the Pod with a projected token

The ServiceAccount turns automatic token mounting off, but `shuttle` must call the API server, so it needs a token. A projected `serviceAccountToken` volume gives it one with a lifetime you choose. Without an `audience` field, the token is issued for the API server itself.

Delete the old Pod:

```sh
kubectl -n starfleet-032-020-02-02 delete pod shuttle
```

```text
pod "shuttle" deleted from starfleet-032-020-02-02 namespace
```

Save this as `pod-shuttle.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: shuttle
  namespace: starfleet-032-020-02-02
  labels:
    app: shuttle
spec:
  serviceAccountName: shuttle-reader
  automountServiceAccountToken: false
  restartPolicy: Never
  containers:
  - name: shuttle
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
          expirationSeconds: 900
          path: token
```

Apply it:

```sh
kubectl apply -f pod-shuttle.yaml
```

```text
pod/shuttle created
```

Then check the result:

```sh
kubectl -n starfleet-032-020-02-02 wait --for=condition=Ready pod/shuttle --timeout=90s
kubectl -n starfleet-032-020-02-02 exec shuttle -- ls /var/run/tokens /var/run/secrets/kubernetes.io/serviceaccount
```

```text
pod/shuttle condition met
ls: /var/run/secrets/kubernetes.io/serviceaccount: No such file or directory
/var/run/tokens:
token
command terminated with exit code 1
```

The projected token is at `/var/run/tokens/token`, and the default token directory does not exist.

## Step 4: Use the Pod's token from your shell

`kubectl --token` alone does not test the token here: the kind kubeconfig also holds a client certificate, and the API server authenticates the certificate first. So add the token as a separate kubeconfig user, use it with `--user`, and remove it afterwards. The token goes from the Pod into the kubeconfig without being printed:

```sh
kubectl config set-credentials shuttle-token --token="$(kubectl -n starfleet-032-020-02-02 exec shuttle -- cat /var/run/tokens/token)"
kubectl --user=shuttle-token auth whoami
kubectl --user=shuttle-token -n starfleet-032-020-02-02 get pods
kubectl --user=shuttle-token -n starfleet-032-020-02-02 delete pod shuttle --dry-run=server
kubectl --user=shuttle-token -n outpost-032-020-02-02 get pods
kubectl config delete-user shuttle-token
```

```text
User "shuttle-token" set.
ATTRIBUTE                                           VALUE
Username                                            system:serviceaccount:starfleet-032-020-02-02:shuttle-reader
UID                                                 460510c5-4ddf-45ce-8ff7-96ff0cd20ad9
Groups                                              [system:serviceaccounts system:serviceaccounts:starfleet-032-020-02-02 system:authenticated]
Extra: authentication.kubernetes.io/credential-id   [JTI=b76834b3-cbaf-469d-a3de-2cd880a45cb4]
Extra: authentication.kubernetes.io/node-name       [astro-ats-032-lab-020-02-02-worker]
Extra: authentication.kubernetes.io/node-uid        [698a2c50-0c59-4ae0-8779-c599e8e5f09f]
Extra: authentication.kubernetes.io/pod-name        [shuttle]
Extra: authentication.kubernetes.io/pod-uid         [848133bc-072f-4747-88e2-e2310e8f39e1]
NAME      READY   STATUS    RESTARTS   AGE
shuttle   1/1     Running   0          22s
Error from server (Forbidden): pods "shuttle" is forbidden: User "system:serviceaccount:starfleet-032-020-02-02:shuttle-reader" cannot delete resource "pods" in API group "" in the namespace "starfleet-032-020-02-02"
Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:starfleet-032-020-02-02:shuttle-reader" cannot list resource "pods" in API group "" in the namespace "outpost-032-020-02-02"
```

The API server identifies the token as `shuttle-reader` and even records the Pod and node it belongs to. The token can list Pods in its own namespace and nothing else. The `--dry-run=server` option makes the API server check the delete request without running it. The output leaves out the last line, which confirms that `kubectl config delete-user` removed `shuttle-token` from your kubeconfig file.
