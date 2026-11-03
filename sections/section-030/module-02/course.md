---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Authentication, Anonymous Access And Authorization Modes

The first question for any API request is who is asking. The Kubernetes API server answers it with authentication, and a wrong answer is expensive. If the server accepts a weak credential, or treats a caller without a credential as a real user, every later check works on bad information. This module looks at the methods the API server uses to identify a caller, at anonymous access and the bindings that make it dangerous, and at the authorization modes that decide what an identified caller may do.

Keep one sentence in mind for this module: **authentication names the caller, anonymous access is a caller with no name, and every grant to that caller is open to the whole network.** You will read your own identity and the claims in a ServiceAccount token, find and remove a risky binding that opens the API to anonymous callers, and test an identity with impersonation.

The module has three parts. **Authentication Methods And Identities** lists the methods, shows the user and groups they produce and reads a token. **Anonymous Access In Practice** sends anonymous requests, finds the binding that allows them and removes it. **Authorization Modes And Impersonation** reads the `--authorization-mode` flag, explains the modes and shows how impersonation tests and abuses an identity.

## Learning objectives

After this module you can:

- Name the authentication methods of the API server and the user name and groups that each produces.
- Read the claims of a ServiceAccount token and explain why an invalid token returns `401` and is not treated as anonymous.
- Explain what `--anonymous-auth` does and which bindings give anonymous callers more than health and version paths.
- Find and remove a binding to `system:anonymous`, `system:unauthenticated` or `system:authenticated` that is wider than needed.
- Name the authorization modes, say how several modes combine and say why `AlwaysAllow` must never be used.
- Test an identity with `--as` and explain why the `impersonate` verb is a high-risk grant.

## Before you start

You need Kubernetes basics: Pods, Deployments, namespaces and `kubectl exec`. Basic RBAC helps: a Role lists permissions and a binding gives them to a subject.

The commands run against a playground cluster. Your terminal must use the playground's private kubeconfig, the file that holds the cluster address and credentials for `kubectl`. Run these two commands once in every new terminal:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-030-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-030-02" || exit 1
```

The playground is a `kind` cluster running Kubernetes 1.35 with one control-plane node and one worker node. Your own credentials have the `cluster-admin` role. The cluster starts with this content:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The Deployment `probe` with two replicas, which run Python and are used to send API requests. The Service `probe`. The pod `shuttle`, a client with BusyBox tools |
| `outpost` | The pod `drifter`, a client with BusyBox tools |

Two ClusterRoleBindings exist from the start: `anonymous-viewer`, which gives the `view` ClusterRole to the group `system:unauthenticated`, and `ops-viewer`, which gives `view` to the group `ops`.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
