---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Remove Anonymous Access To The API Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-030-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-030-02-01" || exit 1
```

Keep this connection selected throughout the task. Every script supplied by the lab refuses a different context.

## Inspect And Explain

Anonymous requests receive the user `system:anonymous` and the group `system:unauthenticated`, and then go through authorization. Find the binding that names those subjects:

```sh
kubectl get clusterrolebindings -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.roleRef.name}{"\t"}{.subjects[*].name}{"\n"}{end}'
kubectl auth can-i list pods -n starfleet --as=system:anonymous --as-group=system:unauthenticated
```

The first command lists the bindings with the role and the subjects. The line for `anonymous-viewer` shows `view` and `system:unauthenticated`. The second command prints `yes`, which confirms the effect. The binding `ops-viewer` names a different group and is not part of the fault.

Delete the binding that grants access to anonymous callers:

```sh
kubectl delete clusterrolebinding anonymous-viewer
```

## Verify The Result

The anonymous request is sent from a `probe` Pod, and the status code is printed. The authorizer needs a short time to see the change, so repeat a request that still shows `200`.

```sh
kubectl -n starfleet exec deployment/probe -- python -c "import ssl,urllib.request as r,urllib.error as e;c=ssl.create_default_context(cafile='/var/run/secrets/kubernetes.io/serviceaccount/ca.crt')
try:
    print(r.urlopen('https://kubernetes.default.svc/api/v1/namespaces/starfleet/pods',context=c,timeout=5).status)
except e.HTTPError as x:
    print(x.code)"
kubectl auth can-i list pods -n starfleet --as=ops-user --as-group=ops
```

The first command prints `403`. Replace the path with `/version` and the same command prints `200`. The second command prints `yes`.


After recording the result, remove this independent lab with `astrona destroy ats-032-lab-030-02-01`.

## Common pitfalls

> [!WARNING]
> Delete the binding, not the role `view` or a built-in role. Keep `ops-viewer`. Test as the anonymous subject and not as `cluster-admin`, which passes every check.