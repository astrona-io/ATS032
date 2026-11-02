---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Disable Automounting And Minimize Permissions

A workload that does not call the Kubernetes API should not receive an API credential. Kubernetes has one field for this, `automountServiceAccountToken`, and it exists in two places with a clear order of precedence. This part sets it on a ServiceAccount, overrides it on a pod, changes the `default` account of a namespace and shows how to keep a newly created account without permissions.

## Two places for one setting

The field `automountServiceAccountToken` is a boolean. It can appear in the ServiceAccount object and in the pod `spec`. If the pod sets it, the pod value is used. If the pod leaves it out, the value from the ServiceAccount is used. If neither sets it, the token is mounted. The setting is read when the pod is created. It does not change pods that are already running.

| Pod setting | ServiceAccount setting | Token mounted |
| --- | --- | --- |
| not set | not set | yes |
| not set | `false` | no |
| `false` | `true` or not set | no |
| `true` | `false` | yes |

The last row matters for review work. A ServiceAccount that says `false` does not protect a namespace on its own, because any pod can say `true` again. A pod-level `false` is the strongest local setting, and an admission policy is the way to enforce it for everyone.

## Disable it in a ServiceAccount

The `outpost` namespace gets a new ServiceAccount named `quiet`. It sets `automountServiceAccountToken: false`, so every pod that uses it gets no token unless the pod asks for one. Two pods use it. The pod `quiet-reader` leaves the pod-level field out. The pod `quiet-override` sets it to `true`.

<!-- astrona:playground:renew -->

Save this as `serviceaccount-quiet.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: quiet
  namespace: outpost
automountServiceAccountToken: false
---
apiVersion: v1
kind: Pod
metadata:
  name: quiet-reader
  namespace: outpost
spec:
  serviceAccountName: quiet
  restartPolicy: Never
  containers:
    - name: reader
      image: docker.io/library/busybox:1.37.0
      command: ["sh", "-c", "sleep 3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: quiet-override
  namespace: outpost
spec:
  serviceAccountName: quiet
  automountServiceAccountToken: true
  restartPolicy: Never
  containers:
    - name: reader
      image: docker.io/library/busybox:1.37.0
      command: ["sh", "-c", "sleep 3600"]
```

Apply it:

```sh
kubectl apply -f serviceaccount-quiet.yaml
```

Then check the result. The first command waits until both pods are ready. The next two look for the token directory in each container:

```sh
kubectl -n outpost wait --for=condition=Ready pod/quiet-reader pod/quiet-override --timeout=90s
kubectl -n outpost exec quiet-reader -- ls /var/run/secrets/kubernetes.io/serviceaccount
kubectl -n outpost exec quiet-override -- ls /var/run/secrets/kubernetes.io/serviceaccount
```

The command for `quiet-reader` fails and exits with an error, because the directory does not exist: the ServiceAccount setting removed the volume. The command for `quiet-override` lists `ca.crt`, `namespace` and `token`, because the pod-level `true` takes precedence over the ServiceAccount. The check you run on a pod is always the same: does the directory exist inside the container.

## Change the default account

A namespace has a `default` ServiceAccount that you cannot delete for long, because the controller creates it again. You can patch it, though. This turns off mounting for every pod in the namespace that uses `default` and does not set the field itself. The command patches the `default` account of `outpost`:

```sh
kubectl -n outpost patch serviceaccount default -p '{"automountServiceAccountToken": false}'
```

The patch does not touch pods that already run. The pod `drifter` was created before the patch, so it still has its token. To prove that the setting applies to new pods, save this as `pod-plain-check.yaml`. It names no ServiceAccount:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: plain-check
  namespace: outpost
spec:
  restartPolicy: Never
  containers:
    - name: reader
      image: docker.io/library/busybox:1.37.0
      command: ["sh", "-c", "sleep 3600"]
```

Apply it:

```sh
kubectl apply -f pod-plain-check.yaml
```

Then check the result. Compare the old pod with the new pod:

```sh
kubectl -n outpost wait --for=condition=Ready pod/plain-check --timeout=90s
kubectl -n outpost exec drifter -- ls /var/run/secrets/kubernetes.io/serviceaccount
kubectl -n outpost exec plain-check -- ls /var/run/secrets/kubernetes.io/serviceaccount
```

The `drifter` pod lists the three files. The `plain-check` pod fails, because it was admitted after the patch. To change `drifter`, you delete it and create it again, which for a Deployment means a rollout.

## Keep new accounts small

Mounting and permissions are two separate controls. Disabling the mount hides the token from the container. Permissions limit what the token can do if it leaks, and a workload that does call the API still needs a token. The rules for new accounts are short:

- Create one ServiceAccount for each workload that needs the API. Do not share one account between unrelated workloads.
- Give a new account no permissions at first, then add only the verbs and resources the workload uses.
- Never bind a Role or ClusterRole to `default`, and never bind to the groups `system:serviceaccounts` or `system:serviceaccounts:<namespace>`, which contain all accounts.
- Set `automountServiceAccountToken: false` on accounts and pods that do not call the API.

`kubectl create serviceaccount` creates an account with no grants. Check it, and look for broad bindings that name accounts. The last command lists RoleBindings in all namespaces with their subjects. Read the `SERVICEACCOUNTS` column for `default`:

```sh
kubectl -n outpost create serviceaccount reporter
kubectl auth can-i --list -n outpost --as=system:serviceaccount:outpost:reporter
kubectl get rolebindings -A -o wide
```

The new account `reporter` has only the rules that every authenticated identity receives. The binding list shows which Roles reach which accounts. In a clean namespace, no binding names `default`.

You now know the order of precedence between the pod and the ServiceAccount, how to set the default for a namespace, and how to keep new accounts free of grants. A workload that really calls the API still needs a token, and the next question is how to make that token short-lived and limited.

## Common pitfalls

> [!WARNING]
> - **Setting `false` on the ServiceAccount and stopping there.** A pod can set `true` and mount the token again.
> - **Expecting a patch to change running pods.** The field is read at pod creation. Recreate the pods.
> - **Confusing mounting with permissions.** A pod without a token still belongs to a ServiceAccount, and the grants of that account still exist.
> - **Putting `automountServiceAccountToken` in the container section.** It belongs to the pod `spec`, next to `serviceAccountName`.
