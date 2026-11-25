# Lock Down the Default ServiceAccount: Solution

Kubernetes creates a ServiceAccount named `default` in every namespace, and every Pod that does not name a ServiceAccount runs as it. A permission given to `default` therefore reaches every such Pod, now and in the future. The fix has three parts: remove the bindings, stop the token mount, and recreate the running Pods so the change reaches them.

## Step 1: Find the bindings that reach default

First connect to the lab cluster:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-020-02-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-020-02-03" || exit 1
```

List RoleBindings and ClusterRoleBindings with the ServiceAccount names among their subjects, and keep the lines that end in `default`:

```sh
kubectl get rolebindings -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,ROLE:.roleRef.name,SERVICEACCOUNTS:.subjects[?(@.kind=="ServiceAccount")].name' | grep -E 'NAMESPACE|default$'
kubectl get clusterrolebindings -o custom-columns='NAME:.metadata.name,ROLE:.roleRef.name,SERVICEACCOUNTS:.subjects[?(@.kind=="ServiceAccount")].name' | grep -E 'NAME|default$'
```

```text
NAMESPACE                 NAME                                                ROLE                                             SERVICEACCOUNTS
outpost-032-020-02-03     drifter-view                                        view                                             default
starfleet-032-020-02-03   default-pod-access                                  pod-access                                       default
NAME                                                            ROLE                                                                   SERVICEACCOUNTS
```

Two RoleBindings reach a `default` ServiceAccount, and no ClusterRoleBinding does. `drifter-view` gives the built-in ClusterRole `view` to `default` in `outpost-032-020-02-03`, and `default-pod-access` gives the Role `pod-access` to `default` in `starfleet-032-020-02-03`.

## Step 2: Remove the bindings and keep the Role

Delete only the bindings. The Role `pod-access` grants nothing by itself; it does harm only when a binding gives it to someone:

```sh
kubectl -n starfleet-032-020-02-03 delete rolebinding default-pod-access
kubectl -n outpost-032-020-02-03 delete rolebinding drifter-view
```

```text
rolebinding.rbac.authorization.k8s.io "default-pod-access" deleted from starfleet-032-020-02-03 namespace
rolebinding.rbac.authorization.k8s.io "drifter-view" deleted from outpost-032-020-02-03 namespace
```

Then check the result. The Role is still there, and neither `default` ServiceAccount can list Pods:

```sh
kubectl -n starfleet-032-020-02-03 get role pod-access
kubectl auth can-i list pods -n starfleet-032-020-02-03 --as=system:serviceaccount:starfleet-032-020-02-03:default
kubectl auth can-i list pods -n outpost-032-020-02-03 --as=system:serviceaccount:outpost-032-020-02-03:default
```

```text
NAME         CREATED AT
pod-access   2026-11-17T21:37:07Z
no
no
```

## Step 3: Turn token mounting off on both default ServiceAccounts

The `default` ServiceAccount already exists, so patch it instead of writing a new file. The loop runs the same patch in both namespaces:

```sh
for namespace in starfleet-032-020-02-03 outpost-032-020-02-03; do
  kubectl -n "$namespace" patch serviceaccount default -p '{"automountServiceAccountToken": false}'
done
```

```text
serviceaccount/default patched
serviceaccount/default patched
```

## Step 4: Recreate the Pods

The ServiceAccount admission controller adds the token volume when a Pod is created, so the patch does not remove the token from Pods that already run. Delete both Pods:

```sh
kubectl -n starfleet-032-020-02-03 delete pod shuttle
kubectl -n outpost-032-020-02-03 delete pod drifter
```

```text
pod "shuttle" deleted from starfleet-032-020-02-03 namespace
pod "drifter" deleted from outpost-032-020-02-03 namespace
```

Save this as `pod-shuttle.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: shuttle
  namespace: starfleet-032-020-02-03
  labels:
    app: shuttle
spec:
  restartPolicy: Never
  containers:
  - name: shuttle
    image: docker.io/library/busybox:1.37.0
    command: ["sh", "-c", "sleep 86400"]
```

Save this as `pod-drifter.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: drifter
  namespace: outpost-032-020-02-03
  labels:
    app: drifter
spec:
  restartPolicy: Never
  containers:
  - name: drifter
    image: docker.io/library/busybox:1.37.0
    command: ["sh", "-c", "sleep 86400"]
```

Apply them:

```sh
kubectl apply -f pod-shuttle.yaml
kubectl apply -f pod-drifter.yaml
```

```text
pod/shuttle created
pod/drifter created
```

Then check that neither container has a token:

```sh
kubectl -n starfleet-032-020-02-03 wait --for=condition=Ready pod/shuttle --timeout=90s
kubectl -n outpost-032-020-02-03 wait --for=condition=Ready pod/drifter --timeout=90s
kubectl -n starfleet-032-020-02-03 exec shuttle -- ls /var/run/secrets/kubernetes.io/serviceaccount
kubectl -n outpost-032-020-02-03 exec drifter -- ls /var/run/secrets/kubernetes.io/serviceaccount
```

```text
pod/shuttle condition met
pod/drifter condition met
ls: /var/run/secrets/kubernetes.io/serviceaccount: No such file or directory
command terminated with exit code 1
ls: /var/run/secrets/kubernetes.io/serviceaccount: No such file or directory
command terminated with exit code 1
```

The Pod files name no ServiceAccount and no `automountServiceAccountToken` field. The ServiceAccount admission controller in the API server fills in `default`, reads `false` from that ServiceAccount and therefore adds no token volume to the Pod.
