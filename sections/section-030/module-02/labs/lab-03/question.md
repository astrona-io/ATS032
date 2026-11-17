---
exam_objectives:
- Restrict access to Kubernetes API
- Use Role Based Access Controls to minimize exposure
---
# Remove AlwaysAllow And Narrow Impersonation Rights

Allow about 12 minutes for the tasks.

The API server of this cluster authorizes every request, because `AlwaysAllow` is in its list of authorization modes. The help desk team also holds an impersonation grant that lets its members act as any user, group or ServiceAccount. Fix both problems.

## Connect to the lab

Use a shell on your own machine. The kubeconfig file holds the address and the credentials of this lab's cluster, and `kubectl` uses it.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-030-02-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-030-02-03" || exit 1
control_plane="astro-ats-032-lab-030-02-03-control-plane"
```

The node of a `kind` cluster is a container on your machine. Open a shell on the control plane node with `podman exec -it "$control_plane" bash`. If your machine uses Docker, write `docker exec` instead. The kube-apiserver runs as a static Pod from `/etc/kubernetes/manifests/kube-apiserver.yaml`. Its probes in that file are TCP checks; leave them as they are.

## Tasks

1. Set `--authorization-mode` of the kube-apiserver to `Node,RBAC`, without `AlwaysAllow`. Wait until the API server is ready again.
2. Change the ClusterRole `helpdesk-impersonate` so that it allows the verb `impersonate` only on `serviceaccounts` with the name `probe`.
3. Replace the ClusterRoleBinding `helpdesk-impersonate` with a RoleBinding `helpdesk-impersonate` in the namespace `starfleet-032-030-02-03`. It binds the ClusterRole `helpdesk-impersonate` to the group `helpdesk`.

After the change, a user without RBAC rules must not be able to list Secrets. Members of the group `helpdesk` must be able to impersonate the ServiceAccount `probe` in `starfleet-032-030-02-03`. They must not be able to impersonate the ServiceAccount `probe` in `outpost-032-030-02-03`, any other ServiceAccount, any user or any group.
