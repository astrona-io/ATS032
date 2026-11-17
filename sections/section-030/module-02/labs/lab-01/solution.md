---
exam_objectives:
- Restrict access to Kubernetes API
---
# Remove RBAC Grants For Anonymous Requests: Solution

Connect to the lab first, so that `kubectl` talks to this lab's cluster:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-030-02-01)"
control_plane="astro-ats-032-lab-030-02-01-control-plane"
```

## Prove that anonymous requests read data

The helper below sends a request with no credentials from the control plane node and prints only the HTTP status code:

```sh
anonymous_status() {
  podman exec $control_plane curl -sk -o /dev/null -w '%{http_code}\n' "https://127.0.0.1:6443$1"
}
anonymous_status /version
anonymous_status /api/v1/namespaces/outpost-032-030-02-01/pods
anonymous_status /api/v1/namespaces/starfleet-032-030-02-01/secrets
```

All three print `200`. The first is expected: the built-in ClusterRole `system:public-info-viewer` lets every caller read `/version`, `/healthz`, `/livez` and `/readyz`. The other two mean that RBAC allows anonymous callers to read cluster data.

## Find the bindings

Print every ClusterRoleBinding with its role and the names of its subjects, and keep only the lines that name an anonymous subject:

```sh
kubectl get clusterrolebindings -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.roleRef.name}{"\t"}{.subjects[*].name}{"\n"}{end}' | grep -E 'system:(anonymous|unauthenticated)'
```

Two lines appear. `system:public-info-viewer` is built in; it carries the label `kubernetes.io/bootstrapping=rbac-defaults`, and it stays. `metrics-reader` grants the ClusterRole `view` to the group `system:unauthenticated` in every namespace. That is the cause of the Pod list.

Do the same for RoleBindings in all namespaces:

```sh
kubectl get rolebindings -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.roleRef.name}{"\t"}{.subjects[*].name}{"\n"}{end}' | grep -E 'system:(anonymous|unauthenticated)'
```

The RoleBinding `support-read` in `starfleet-032-030-02-01` grants the ClusterRole `edit` to the user `system:anonymous`. The role `view` does not include Secrets, but `edit` does, which is why the Secret list worked. A RoleBinding in `kube-public` may also appear; kubeadm creates it so that new nodes can read the cluster information while they join. It is outside this task.

## Remove the bindings

Delete both bindings by name:

```sh
kubectl delete clusterrolebinding metrics-reader
kubectl -n starfleet-032-030-02-01 delete rolebinding support-read
```

## Check the result

Run the same requests again:

```sh
anonymous_status /version
anonymous_status /api/v1/namespaces/outpost-032-030-02-01/pods
anonymous_status /api/v1/namespaces/starfleet-032-030-02-01/secrets
kubectl auth can-i list pods -n starfleet-032-030-02-01 --as=ops-user --as-group=ops
```

`/version` still returns `200`, and the two data requests now return `403`. The caller is still authenticated as `system:anonymous`, but the RBAC authorizer finds no rule that allows the request. The last command prints `yes`, because `ops-viewer` is unchanged.

## Common pitfalls

> [!WARNING]
> - **Searching only ClusterRoleBindings.** A RoleBinding can grant anonymous access inside one namespace. Search both kinds.
> - **Deleting or editing `system:public-info-viewer`.** The API server restores its default roles when it starts, and health checks need that access.
> - **Switching anonymous authentication off as a shortcut.** Requests then get `401`, and on kubeadm clusters the API server probes can fail. The task asks you to remove the grants.
