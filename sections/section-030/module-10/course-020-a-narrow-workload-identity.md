# A Narrow Workload Identity

A workload that calls the API should use an identity made only for it, and that identity should be allowed one job. Today, the `probe` Pods use the `default` ServiceAccount of `starfleet`, which may not list anything in the namespace. If you gave that account more rights, every other Pod that uses it would get them too.

On this page, you build a separate identity for the `probe` Deployment: a ServiceAccount, a Role that reads Services in one namespace, and a binding between them. Then you prove it with requests sent from inside the Pod. The allowed request must work, and everything else must be refused.

## What the identity needs

The identity is made of three objects, all in the `starfleet` namespace:

- A **ServiceAccount** named `lister`. It is the identity itself. Pods that name it in `serviceAccountName` receive a token for it.
- A **Role** named `service-lister`. It allows the verbs `get` and `list` on `services`, and nothing else.
- A **RoleBinding** named `service-lister-bind`. It gives the Role to the ServiceAccount, inside `starfleet` only.

The token that a Pod receives is a JSON Web Token (JWT), a signed piece of text that the API server issued for the ServiceAccount. When a request carries the token, the API server checks its signature and its expiry time. It also checks that the ServiceAccount still exists and is the one the token was issued for. Then it uses the name `system:serviceaccount:starfleet:lister` and the groups of the ServiceAccount for authorization.

![Diagram: the RoleBinding service-lister-bind connects the ServiceAccount lister to the Role service-lister in starfleet; the probe Pods run as lister, so a request to list Services in starfleet is allowed and requests for Pods, Secrets or Services in outpost are refused](images/lister-identity.svg)

The drawing shows how the three objects work together. The Pod runs as `lister`, the RoleBinding links `lister` to the Role, and only the action the Role names is allowed.

## Create the identity

All three objects go in one file, so you create them with one command.

<!-- astrona:playground:renew -->

Save this as `serviceaccount-lister.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: lister
  namespace: starfleet
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: service-lister
  namespace: starfleet
rules:
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: service-lister-bind
  namespace: starfleet
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: service-lister
subjects:
  - kind: ServiceAccount
    name: lister
    namespace: starfleet
```

Apply it:

```sh
kubectl apply -f serviceaccount-lister.yaml
```

```text
serviceaccount/lister created
role.rbac.authorization.k8s.io/service-lister created
rolebinding.rbac.authorization.k8s.io/service-lister-bind created
```

Then check the result from the point of view of the authorizer, the part of the API server that makes the authorization decision:

```sh
kubectl auth can-i list services -n starfleet --as=system:serviceaccount:starfleet:lister
kubectl auth can-i list pods -n starfleet --as=system:serviceaccount:starfleet:lister
kubectl auth can-i list services -n outpost --as=system:serviceaccount:starfleet:lister
```

The first command prints `yes`. The second prints `no`, because the Role does not cover Pods. The third prints `no`, because the RoleBinding lives in `starfleet` and gives no rights in `outpost`.

This check does not yet prove that the workload can use the identity. For that, the workload must run as the ServiceAccount, and its request must authenticate with the ServiceAccount token.

## Run the workload as the identity

A Deployment sets the ServiceAccount of its Pods in the Pod template. When you change the template, the Deployment starts a rollout and replaces its Pods. The command `kubectl set serviceaccount` edits the template for you.

Wait for the rollout to finish, because the old Pods keep their old token until they are replaced:

```sh
kubectl -n starfleet set serviceaccount deployment/probe lister
kubectl -n starfleet rollout status deployment/probe --timeout=180s
```

The last line of the output is `deployment "probe" successfully rolled out`.

Now confirm which ServiceAccount the Pods use:

```sh
kubectl -n starfleet get pods -l app=probe -o custom-columns=NAME:.metadata.name,SA:.spec.serviceAccountName
```

Right after the rollout, the output can still list the old Pods:

```text
NAME                     SA
probe-7789f7bdd6-7n6mq   lister
probe-7789f7bdd6-z4x2g   lister
probe-7db6ffd7d6-slchb   default
probe-7db6ffd7d6-v4d85   default
```

The two rows with `default` are the old replicas. `kubectl get pods` shows them as `Terminating`, and they disappear after their grace period of 30 seconds. Run the command again after that, and only the two `lister` rows remain. Your Pod names differ from these.

## Send the requests

With the new Pods in place, you can test the identity the way the workload uses it. The `call_api` function runs a script in a `probe` Pod and prints the HTTP status code. Its first argument is the path, and its second is `anon` or `token`. If the function is not defined in this terminal, define it first:

```sh
call_api() {
  kubectl -n starfleet exec -i deployment/probe -- python - "$@" <<'PY'
import sys, ssl, urllib.request, urllib.error
from pathlib import Path
path, mode = sys.argv[1], sys.argv[2]
root = Path('/var/run/secrets/kubernetes.io/serviceaccount')
ctx = ssl.create_default_context(cafile=str(root / 'ca.crt'))
req = urllib.request.Request('https://kubernetes.default.svc' + path)
if mode == 'token':
    req.add_header('Authorization', 'Bearer ' + (root / 'token').read_text())
try:
    print(urllib.request.urlopen(req, context=ctx, timeout=5).status)
except urllib.error.HTTPError as e:
    print(e.code)
PY
}
```

Send one request that must work and three that must fail:

```sh
call_api /api/v1/namespaces/starfleet/services token
call_api /api/v1/namespaces/starfleet/pods token
call_api /api/v1/namespaces/starfleet/secrets token
call_api /api/v1/namespaces/outpost/services token
```

```text
200
403
403
403
```

The first request prints `200`. The token authenticates the caller as `lister`, and the Role allows listing Services in `starfleet`. The other three print `403`, because Pods and Secrets are not in the rule, and the RoleBinding does not reach `outpost`.

A pair of results like this proves both sides of the design. The workload can do its job, and a stolen token cannot do more than that job.

## Why one identity per workload

The `default` ServiceAccount is shared by every Pod in the namespace that names no other account. A grant on `default` therefore reaches all of those Pods. A ServiceAccount for each workload has three advantages:

- each grant is visible in one place;
- the audit records show which workload made a request;
- when you remove the workload and its ServiceAccount, its permissions go too.

Keep the Role itself small as well. List the exact `resources` and `verbs`. Add `resourceNames` when the workload needs only a few named objects. Prefer a Role and a RoleBinding over a ClusterRole and a ClusterRoleBinding when the work happens in one namespace. If the workload does not call the API at all, give it no permissions and turn off token mounting.

You now have a workload with an identity that allows one action, and you checked it from inside the Pod. But every one of these requests goes to the same API server endpoint. The open question is which settings on the API server and the kubelet decide who can reach them at all.

## Common pitfalls

> [!WARNING]
> - **Checking only with `kubectl auth can-i`.** It does not prove that the Pod runs as the ServiceAccount or that the request authenticates. Send a request from the Pod.
> - **Testing before the rollout finishes.** Old replicas still use the old ServiceAccount.
> - **Granting `list` and forgetting that `list` returns full objects.** The result of `list` on Secrets contains every Secret value.
> - **Granting on `default`.** Every Pod that names no ServiceAccount receives the grant.
> - **Using `-k` or turning off certificate checking to make a call work.** Use `ca.crt` from the ServiceAccount mount.
