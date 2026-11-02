---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# A Narrow Workload Identity

A workload that calls the API should do so with an identity made for it, and that identity should be allowed one job. This part builds that identity for the `probe` Deployment: a ServiceAccount, a Role that reads Services in one namespace, and a binding. Then it proves, with requests sent from inside the Pod, that the allowed request works and that everything else is refused.

## What the identity needs

Three objects are involved, all in `starfleet`.

- A **ServiceAccount** named `lister`. It is the identity. Pods that name it in `serviceAccountName` receive a token for it.
- A **Role** named `service-lister`. It allows `get` and `list` on `services` and nothing else.
- A **RoleBinding** named `service-lister-bind`. It gives the Role to the ServiceAccount inside `starfleet`.

The token that a Pod receives is a JWT issued for the ServiceAccount. The API server checks its signature, its expiry and that the ServiceAccount still exists and is the one the token was bound to. Then it uses the name `system:serviceaccount:starfleet:lister` and the groups of the ServiceAccount for authorization.

## Create the identity

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

Then check the result from the authorizer's point of view:

```sh
kubectl auth can-i list services -n starfleet --as=system:serviceaccount:starfleet:lister
kubectl auth can-i list pods -n starfleet --as=system:serviceaccount:starfleet:lister
kubectl auth can-i list services -n outpost --as=system:serviceaccount:starfleet:lister
```

The first command prints `yes`. The second prints `no`, because the Role does not cover Pods. The third prints `no`, because the binding is in `starfleet`. This check does not prove that the workload can use the identity. The workload must run as the ServiceAccount, and the request must authenticate with its token.

## Run the workload as the identity

A Deployment changes its ServiceAccount through the Pod template, which starts a rollout. `kubectl set serviceaccount` edits the template for you. Wait for the rollout to finish, because the old Pods keep their old token until they are replaced:

```sh
kubectl -n starfleet set serviceaccount deployment/probe lister
kubectl -n starfleet rollout status deployment/probe --timeout=180s
```

Confirm what the new Pods use:

```sh
kubectl -n starfleet get pods -l app=probe -o custom-columns=NAME:.metadata.name,SA:.spec.serviceAccountName
```

Each row of the output shows `lister` in the `SA` column. If one row still shows `default`, that Pod is an old replica that has not been replaced yet.

## Send the requests

If the function `call_api` is not defined in this terminal, define it first. It runs a script in a probe Pod and prints the HTTP status code. The first argument is the path and the second is `anon` or `token`.

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

Send one allowed request and three that must fail:

```sh
call_api /api/v1/namespaces/starfleet/services token
call_api /api/v1/namespaces/starfleet/pods token
call_api /api/v1/namespaces/starfleet/secrets token
call_api /api/v1/namespaces/outpost/services token
```

The first request prints `200`: the token authenticates as `lister`, and the Role allows listing Services in `starfleet`. The other three print `403`, because Pods and Secrets are not in the rule and the binding does not reach `outpost`. A pair of results like this proves both sides of the design: the workload can do its job, and a stolen token cannot do more.

## Why one identity per workload

The `default` ServiceAccount is shared by every Pod in the namespace that names no other account. A grant on `default` therefore reaches all of them. A ServiceAccount per workload makes a grant visible in one place, makes its audit trail readable, and means that removing a workload also removes its permissions.

Keep the Role small in three ways. List the exact `resources` and `verbs`. Add `resourceNames` when the workload needs only a few named objects. Prefer a Role and RoleBinding over a ClusterRole and ClusterRoleBinding when the work is in one namespace. If the workload does not call the API at all, give it no permissions and turn off token mounting.

You now have a workload with an identity that allows one action, and you checked it from inside the Pod. The endpoint that serves all of these requests also needs hardening, which is the last part.

## Common pitfalls

> [!WARNING]
> - **Checking only with `kubectl auth can-i`.** It does not prove that the Pod runs as the ServiceAccount or that the request authenticates. Send a request from the Pod.
> - **Testing before the rollout finishes.** Old replicas still use the old ServiceAccount.
> - **Granting `list` and forgetting that `list` returns full objects.** The result of `list` on Secrets contains every Secret value.
> - **Granting on `default`.** Every Pod that names no account receives the grant.
> - **Using `-k` or disabling certificate verification to make a call work.** Use `ca.crt` from the ServiceAccount mount.
