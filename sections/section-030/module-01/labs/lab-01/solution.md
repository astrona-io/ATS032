---
exam_objectives:
- Restrict access to Kubernetes API
---
# Give A Workload A Narrow ServiceAccount: Solution

Connect to the lab first, so that `kubectl` talks to this lab's cluster:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-030-01-01)"
NS=starfleet-032-030-01-01
```

## Create the identity and its rights

A ServiceAccount is a Kubernetes identity for a workload. A Role lists allowed verbs on resources in one namespace, and a RoleBinding gives the rights of a Role to a subject. Save this as `serviceaccount-observer.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: observer
  namespace: starfleet-032-030-01-01
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: observer-reader
  namespace: starfleet-032-030-01-01
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: observer-read
  namespace: starfleet-032-030-01-01
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: observer-reader
subjects:
- kind: ServiceAccount
  name: observer
  namespace: starfleet-032-030-01-01
```

Apply it:

```sh
kubectl apply -f serviceaccount-observer.yaml
```

Then ask the authorizer what the new identity may do. The first two commands print `yes`; the last two print `no`:

```sh
kubectl auth can-i list pods -n $NS --as=system:serviceaccount:$NS:observer
kubectl auth can-i get pods -n $NS --as=system:serviceaccount:$NS:observer
kubectl auth can-i get secrets -n $NS --as=system:serviceaccount:$NS:observer
kubectl auth can-i list services -n outpost-032-030-01-01 --as=system:serviceaccount:$NS:observer
```

## Run the Deployment as the identity

The field `spec.template.spec.serviceAccountName` sets the ServiceAccount of every Pod the Deployment creates. The command below changes that field, and the Deployment controller then replaces both Pods:

```sh
kubectl -n $NS set serviceaccount deployment probe observer
kubectl -n $NS rollout status deployment/probe --timeout=180s
```

## Send the requests from the Pod

`kubectl auth can-i` only asks the authorizer. It does not prove that the Pod uses the token of `observer`. The kubelet mounts the token and the certificate authority of the cluster into every Pod at `/var/run/secrets/kubernetes.io/serviceaccount`. Save this short Python script as `in-pod-request.py`. It sends a GET request to the path you give it and prints the HTTP status code:

```python
import ssl, sys, urllib.request, urllib.error
root = '/var/run/secrets/kubernetes.io/serviceaccount'
context = ssl.create_default_context(cafile=root + '/ca.crt')
request = urllib.request.Request('https://kubernetes.default.svc' + sys.argv[1],
    headers={'Authorization': 'Bearer ' + open(root + '/token').read()})
try:
    print(urllib.request.urlopen(request, context=context, timeout=5).status)
except urllib.error.HTTPError as error:
    print(error.code)
```

Run it inside one `probe` Pod for the three paths:

```sh
kubectl -n $NS exec -i deploy/probe -- python - /api/v1/namespaces/$NS/pods < in-pod-request.py
kubectl -n $NS exec -i deploy/probe -- python - /api/v1/namespaces/$NS/secrets < in-pod-request.py
kubectl -n $NS exec -i deploy/probe -- python - /api/v1/namespaces/outpost-032-030-01-01/services < in-pod-request.py
```

The Pod list returns `200`. The Secrets and the Services of the other namespace return `403`. The API server authenticated each request as `observer`, and the RBAC authorizer allowed only what the Role names.

## Common pitfalls

> [!WARNING]
> - **Checking only with `kubectl auth can-i`.** It does not prove that the Pods run as the new ServiceAccount. Send a request from a Pod.
> - **Using `resources: ["*"]` or `verbs: ["*"]`.** The task asks for `get` and `list` on Pods only.
> - **Testing an old Pod.** The Deployment replaces its Pods when the ServiceAccount changes. Wait for the rollout before you test.
