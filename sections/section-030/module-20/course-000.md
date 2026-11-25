# Authentication, Anonymous Access And Authorization Modes

Every request to the Kubernetes API server starts with one question: who is asking? The API server answers it with authentication, the step that checks the credential of a request and turns it into an identity. If this step accepts a weak credential, or treats a caller without a credential as a real user, every later check works on wrong information.

A caller without a credential is called anonymous. The API server can let anonymous requests through to the next step, and then the bindings in the cluster decide what they may do. A binding that grants too much to anonymous callers opens the API to anyone who can reach its network port.

After authentication comes authorization, the step that decides what an identified caller may do. The API server runs one or more authorizers, and the flag `--authorization-mode` sets which ones and in which order. One wrong mode in that list can make every other rule pointless.

## What you will learn

After this module, you can:

- name the authentication methods of the API server and the user name and groups that each method produces;
- read the claims of a ServiceAccount token, and explain why an invalid token returns `401` and is not treated as anonymous;
- explain what `--anonymous-auth` does and which bindings give anonymous callers more than the health and version paths;
- find and remove a binding to `system:anonymous`, `system:unauthenticated` or `system:authenticated` that is wider than needed;
- name the authorization modes, say how several modes combine, and say why `AlwaysAllow` must never be used;
- test an identity with `--as`, and explain why the `impersonate` verb is a high-risk grant.

## How the module is laid out

You start with **Authentication Methods And Identities**, which lists the methods, shows the user name and groups they produce, and opens a ServiceAccount token. **Anonymous Access In Practice** then sends requests without a credential, finds the binding that lets them read Pods, and removes it. **Authorization Modes And Impersonation** closes the module. It reads the `--authorization-mode` flag of the live API server, explains each mode, and shows how impersonation can test an identity and also abuse it.

A lab follows each part, so you can practise the skill right after you read about it.

## Before you start

You should know the Kubernetes basics: Pods, Deployments, namespaces and `kubectl exec`. Basic RBAC (role-based access control) helps too: a Role lists permissions, and a binding gives those permissions to a subject, which is a user, a group or a ServiceAccount.

## Your playground

Your playground is a virtual machine (VM) with a single-node Kubernetes v1.35 cluster that `kubeadm` created. You need a real node here, because some steps read the manifest of the API server on the node itself. Run every command of the module in a shell on that VM. Open the shell from your own machine with this command:

```sh
astrona ssh astro-ats-032-playground-030-02
```

You are the user `student`. You can run commands as root with `sudo`. `kubectl` already works for this cluster, and its credentials belong to the user `kubernetes-admin`, which has the `cluster-admin` role. The only node is called `controlplane`. It runs the control plane, with the API server as a static Pod, and it also runs the example workloads.

The cluster starts with these objects:

| Namespace | Object | What it is |
| --- | --- | --- |
| `starfleet` | `probe` Deployment, two pods, labels `app: probe` and `release: probe` | A small Python web server on port 8080. You use its Python to send requests to the API |
| `starfleet` | `probe-code` ConfigMap | Holds `server.py`, the code of the `probe` web server |
| `starfleet` | `probe` Service | Port 80, forwards to port 8080 of the `probe` pods |
| `starfleet` | `shuttle` pod, label `app: shuttle` | A client pod with BusyBox tools |
| `outpost` | `drifter` pod, label `app: drifter` | A client pod with BusyBox tools, in another namespace |
| cluster-wide | `anonymous-viewer` ClusterRoleBinding | Gives the `view` ClusterRole to the group `system:unauthenticated` |
| cluster-wide | `ops-viewer` ClusterRoleBinding | Gives the `view` ClusterRole to the group `ops` |

All of these pods use the `default` ServiceAccount of their namespace. Launch your playground now, and keep it running while you read:

<!-- astrona:playground -->
