---
exam_objectives:
- Restrict access to Kubernetes API
- Use Role Based Access Controls to minimize exposure
---
# Remove AlwaysAllow And Narrow Impersonation Rights

Allow about 12 minutes for the tasks.

The API server of this cluster authorizes every request, because `AlwaysAllow` is in its list of authorization modes. The help desk team also holds an impersonation grant that lets its members act as any user, group or ServiceAccount. Fix both problems.

## Connect to the lab

The lab is a virtual machine (VM) with one Kubernetes node. Open a shell on it from your own machine:

```sh
astrona ssh astro-ats-032-lab-030-02-03
```

You are the user `student`. You can run commands as root with `sudo`, and `kubectl` already works for this cluster. The node is called `controlplane`. The kubelet on that node runs the kube-apiserver as a static Pod from `/etc/kubernetes/manifests/kube-apiserver.yaml`. Only root can change that file. The probes of the kube-apiserver in that file are TCP checks. Leave them as they are.

## Tasks

1. Set `--authorization-mode` of the kube-apiserver to `Node,RBAC`, without `AlwaysAllow`. Wait until the API server is ready again.
2. Change the ClusterRole `helpdesk-impersonate` so that it allows the verb `impersonate` only on `serviceaccounts` with the name `probe`.
3. Replace the ClusterRoleBinding `helpdesk-impersonate` with a RoleBinding `helpdesk-impersonate` in the namespace `starfleet-032-030-02-03`. It binds the ClusterRole `helpdesk-impersonate` to the group `helpdesk`.

After the change, a user without RBAC rules must not be able to list Secrets. Members of the group `helpdesk` must be able to impersonate the ServiceAccount `probe` in `starfleet-032-030-02-03`. They must not be able to impersonate the ServiceAccount `probe` in `outpost-032-030-02-03`, any other ServiceAccount, any user or any group.

## How the answer is checked

The grader runs two checks:

- The manifest and the running `kube-apiserver-controlplane` Pod both use the modes `Node` and `RBAC` without `AlwaysAllow`, and a `SubjectAccessReview` for a user without RBAC rules who lists Secrets is not allowed.
- A `SubjectAccessReview` for the group `helpdesk` allows impersonating the ServiceAccount `probe` in `starfleet-032-030-02-03` through RBAC. It refuses the ServiceAccount `probe` in `outpost-032-030-02-03`, the ServiceAccount `default` in `starfleet-032-030-02-03`, the user `kubernetes-admin` and the group `system:masters`.
