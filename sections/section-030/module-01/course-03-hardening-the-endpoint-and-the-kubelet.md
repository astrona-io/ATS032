---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Hardening The Endpoint And The Kubelet

The first two parts looked at requests from the inside. This part looks at the server side: which settings decide who can reach the API server, how callers are authenticated and authorized, how a node is limited, and what is recorded. The API server and the kubelet are configured through files and flags on the control-plane and worker hosts. In the playground you can read the live API server settings. Changing them is described here, but you do not change the playground.

## Where the settings live

On a kubeadm cluster, `kube-apiserver` runs as a static Pod. The kubelet starts it from the manifest `/etc/kubernetes/manifests/kube-apiserver.yaml` on the control-plane node. The flags are in the `command` list of that manifest. When you save a change to the file, the kubelet notices it and recreates the Pod. A wrong flag or a bad file path makes the API server fail to start, and then `kubectl` stops working too.

The kubelet on every node reads its settings from a configuration file, `/var/lib/kubelet/config.yaml` on kubeadm nodes, and from command-line flags set by the service unit. Restart the kubelet service after you change it.

## Read the live API server flags

You can see the flags from the API with `kubectl`, which is read-only and works from your machine.

<!-- astrona:playground:renew -->

```sh
kubectl -n kube-system get pod -l component=kube-apiserver -o jsonpath='{range .items[0].spec.containers[0].command[*]}{@}{"\n"}{end}'
```

The command prints one flag per line. Look for the flags in this list:

| Flag | What it controls | Expected in a hardened cluster |
| --- | --- | --- |
| `--authorization-mode` | Authorizers asked for each request | `Node,RBAC`. It must not contain `AlwaysAllow` |
| `--anonymous-auth` | Whether unauthenticated requests are treated as `system:anonymous` | `false` if nothing needs anonymous health checks. Otherwise keep RBAC for anonymous minimal |
| `--enable-admission-plugins` | Extra admission plugins | Contains `NodeRestriction` |
| `--client-ca-file` | CA that signs client certificates | Set |
| `--tls-min-version` | Lowest TLS version offered | `VersionTLS12` or higher |
| `--profiling` | The `/debug/pprof` endpoints | `false` |
| `--audit-policy-file` and `--audit-log-path` | Audit logging | Both set when audit logging is required |

In a default kubeadm cluster, you will see `--authorization-mode=Node,RBAC` and `--enable-admission-plugins=NodeRestriction`. You will not see `--anonymous-auth`, because its default is `true`, and you will not see the audit flags, because kubeadm does not enable auditing by default. Missing flags show where the defaults leave work to do.

Anonymous access has a middle path. The structured authentication configuration, passed with `--authentication-config`, can allow anonymous requests only for a list of paths such as `/livez`, `/readyz` and `/healthz`. This keeps health checks that need no credential and refuses everything else.

## Limit what a node can do: NodeRestriction

Every kubelet authenticates to the API server with a client certificate in the group `system:nodes`. The Node authorizer limits what a kubelet may read, such as the Secrets of the Pods that are bound to its node. The **NodeRestriction** admission plugin limits what it may write. A kubelet can then modify only its own `Node` object and the Pods bound to its own node. It cannot change the labels with the prefix `node-restriction.kubernetes.io/`, so an attacker on a compromised node cannot label that node into a scheduling rule that attracts sensitive workloads. Make sure `NodeRestriction` is in `--enable-admission-plugins` and that `Node` is in `--authorization-mode`.

## Harden the kubelet

The kubelet has its own API on port 10250. It can list Pods, read logs and run commands in containers. Three settings in the kubelet configuration file close it:

```yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
readOnlyPort: 0
```

`anonymous.enabled: false` refuses unauthenticated requests to the kubelet. `authorization.mode: Webhook` makes the kubelet ask the API server whether the caller is allowed, in place of the unsafe `AlwaysAllow`. `readOnlyPort: 0` turns off the old unauthenticated read-only port 10255. Kubeadm sets the first two by default. After a change, run `systemctl restart kubelet` on that node.

## Reduce network exposure

Authentication protects the endpoint, but fewer hosts that can reach it means fewer hosts that can try. Port 6443 of the API server should be reachable only from the places that need it: administrators, nodes, and the control-plane components. Use host firewalls, security groups or a private load balancer for this. The same holds for the kubelet port 10250, which only the control plane and monitoring need, and for the etcd ports 2379 and 2380, which only the API server and the other etcd members need. Do not publish the API server on a public address unless you must, and then limit the source addresses.

## Record what happens: audit logging

The API server can write an audit record for each request. A policy file lists rules and, for each, a level. The first matching rule wins.

| Level | What is recorded |
| --- | --- |
| `None` | Nothing |
| `Metadata` | User, time, verb, resource and response code. No request or response body |
| `Request` | Metadata and the request body |
| `RequestResponse` | Metadata, request body and response body |

Save this as `audit-policy.yaml`. It is a reference file to place on the control-plane node, for example at `/etc/kubernetes/audit-policy.yaml`. It records who touched Secrets without writing their values into the log, and records the body of changes to RBAC objects:

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - RequestReceived
rules:
  - level: Metadata
    resources:
      - group: ""
        resources: ["secrets"]
  - level: RequestResponse
    resources:
      - group: "rbac.authorization.k8s.io"
        resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
  - level: Metadata
```

To use it, edit the static Pod manifest. Add `--audit-policy-file=/etc/kubernetes/audit-policy.yaml`, `--audit-log-path=/var/log/kubernetes/audit.log` and rotation flags such as `--audit-log-maxage=30`, `--audit-log-maxbackup=10` and `--audit-log-maxsize=100`. Because the API server runs in a container, also add `hostPath` volumes and `volumeMounts` for the policy file, which can be mounted read-only, and for the log directory. If the volumes are missing, the flags point to paths that do not exist in the container, and the API server does not start.

## Edit the manifest carefully

Before you edit `/etc/kubernetes/manifests/kube-apiserver.yaml`, copy it to a directory outside `/etc/kubernetes/manifests`. The kubelet runs every manifest file it finds in that directory, so a backup stored there starts a second API server and conflicts with the first. After the edit, wait for the Pod to be recreated, then check it with `kubectl -n kube-system get pod -l component=kube-apiserver`. If `kubectl` no longer answers, read the container logs on the node with `crictl ps -a` and `crictl logs <container-id>`, fix the flag, and wait again.

You now know where the API server and kubelet settings live, which ones remove common risks, and how to read them. Together with narrow workload identities, these settings narrow who can reach the API, what they can do, and what is recorded.

## Common pitfalls

> [!WARNING]
> - **Leaving a backup of `kube-apiserver.yaml` in `/etc/kubernetes/manifests`.** The kubelet starts it as another Pod. Keep backups elsewhere.
> - **Adding an audit flag without the matching `hostPath` volume.** The API server cannot open the file and fails to start.
> - **Logging Secrets at `Request` or `RequestResponse` level.** The values are written to the audit log. Use `Metadata` for Secrets.
> - **Assuming a kubeadm default is a hardening setting.** Anonymous auth stays on and audit logging is off until you change them.
> - **Opening the kubelet port 10250 to the whole network.** Limit it to the control plane and monitoring.
