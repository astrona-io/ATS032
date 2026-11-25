# ServiceAccounts And The Default Token

Most pods never call the Kubernetes API, yet most pods carry a credential for it. This happens because Kubernetes adds the credential by itself, unless you tell it not to.

Before you change this behavior, you need to see exactly what Kubernetes adds, which component adds it and what the credential allows. On this page, you inspect the `shuttle` pod and the `default` ServiceAccount.

## How a pod gets an identity

A ServiceAccount is a namespaced API object that represents a workload. Users are for people; ServiceAccounts are for processes that run in pods. Every namespace gets a ServiceAccount named `default`. The ServiceAccount controller inside `kube-controller-manager` creates it.

When the API server receives a pod without the field `spec.serviceAccountName`, the ServiceAccount admission controller sets the field to `default`. An admission controller is a step in the API server that can check or change an object before the API server stores it. This admission controller also rejects a pod that names a ServiceAccount that does not exist.

The same admission step adds a volume to the pod. The kubelet is the node agent that starts containers. It fills that volume and mounts it in every container at `/var/run/secrets/kubernetes.io/serviceaccount`.

The volume is a **projected volume**: one volume that combines several sources. It has three sources:

- A token. The kubelet asks the API server for it with the TokenRequest API and writes it to the file `token`.
- The cluster certificate authority (CA) bundle from the ConfigMap `kube-root-ca.crt`, in the file `ca.crt`. A client uses it to trust the certificate of the API server.
- The namespace of the pod, in the file `namespace`.

![Diagram: the kube-api-access projected volume combines a token, the ca.crt file from the kube-root-ca.crt ConfigMap and the pod namespace, and the kubelet mounts it at /var/run/secrets/kubernetes.io/serviceaccount](images/projected-volume-sources.svg)

The drawing shows the three sources of the projected volume and the three files they become inside the container.

The token is a JSON Web Token (JWT). A JWT is a signed text string that carries claims, such as who the token belongs to and when it expires. The API server signs this token. The token is **bound** to the pod:

- it carries the name and unique ID of the pod and of the ServiceAccount;
- it has an expiry time;
- the API server stops accepting it when the pod is deleted.

The kubelet refreshes the file before the token expires. So the application should read the file again each time it makes a new call, and not keep the value forever.

## Look at the default token in a running pod

Now look at a real pod. Start with the pod `shuttle`. The first command lists the ServiceAccounts in `starfleet`. The second prints which account the pod uses. The third lists the names of its volumes.

<!-- astrona:playground:renew -->

```sh
kubectl -n starfleet get serviceaccount
kubectl -n starfleet get pod shuttle -o jsonpath='{.spec.serviceAccountName}{"\n"}'
kubectl -n starfleet get pod shuttle -o jsonpath='{.spec.volumes[*].name}{"\n"}'
```

The list shows the ServiceAccount `default`. The second command prints `default`, although the pod manifest never named an account: the admission controller filled it in. The third command prints one volume name that starts with `kube-api-access-` and ends in a random suffix. That volume is the projected volume.

Next, list the files in the mount path of the container. The command lists names only. Never print the file `token` in a shared terminal. Anyone who reads it can call the API as this pod until the token expires.

```sh
kubectl -n starfleet exec shuttle -- ls /var/run/secrets/kubernetes.io/serviceaccount
kubectl -n starfleet get pod shuttle -o jsonpath='{.spec.volumes[0].projected.sources[0].serviceAccountToken}{"\n"}'
```

The first command prints three names: `ca.crt`, `namespace` and `token`. The second command prints the settings of the token source as JSON. It shows an `expirationSeconds` value of `3607`, which is a little over one hour, and the path `token`.

There is no `audience` field. This means the token uses the default audience, which is the API server itself.

## What the default account can do

A token only proves an identity. What that identity may do comes from Role-Based Access Control (RBAC), the part of the API server that checks each request against Roles and bindings. A new `default` ServiceAccount has no Role or binding of its own. Ask the API server for its permissions in `starfleet`:

```sh
kubectl auth can-i --list -n starfleet --as=system:serviceaccount:starfleet:default
```

The table that comes back is short. It contains only the rules that every authenticated identity receives from built-in bindings. These include the right to ask what its own permissions are, and read access to a few non-resource URLs such as `/version`. The table has no rule for Pods, Secrets or any other namespaced object.

So a fresh `default` account is harmless. The danger is that clusters change over time. Suppose an administrator binds a Role to `default` to fix one broken application. Every pod in the namespace then gets the same rights, because every pod without a named account uses `default`.

The mounted token then turns any code execution inside one container into API access. Mounting is the first thing to remove, and permissions are the second.

![Diagram: admission sets the default ServiceAccount, the kubelet mounts a projected token, and role bindings decide what a process that uses the token may do](images/default-token-path.svg)

The drawing shows who does what. Admission picks the account, the kubelet mounts the token, and RBAC bindings decide what a request with that token may do.

You have now seen what a default pod receives: an automatic account, a projected token that expires after about an hour, the cluster CA and the namespace. The `default` account has almost no permissions, but the token is present in every container. The open question is how to stop Kubernetes from mounting it.

## Common pitfalls

> [!WARNING]
> - **Assuming the `default` account is powerful.** A new one is not. The risk comes from bindings that someone adds to it later.
> - **Printing the token to check it.** Check that the file exists, not what it contains.
> - **Binding roles to `default`.** Every pod without a named account then gets the rights.
> - **Caching the token in the application.** The kubelet rotates the file, so the application must read it again.
