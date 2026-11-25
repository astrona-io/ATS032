# Restrict Access To The Kubernetes API

The Kubernetes API server (`kube-apiserver`) is the front door of the cluster. Every change to a Pod, a Secret or a Role goes through it, and so does every read of the cluster state. Whoever can send a request that the API server accepts controls a large part of the cluster.

So the API server checks every request before it acts on it. It runs three checks in a fixed order: authentication (who is calling), authorization (may this caller do this action) and admission (is the content of this change acceptable). Hardening means that each check says no to anything that is not needed.

The API server is not the only door. The kubelet, the agent that runs the Pods on each node, has its own API. This module looks at both: how a request is checked, how a workload calls the API with a small identity, and which settings on the API server and the kubelet close the common ways in.

## What you will learn

After this module, you can:

- name the three checks a request passes, and the HTTP status code that each failed check returns;
- test anonymous and authenticated access to the API from inside a Pod;
- give a workload its own ServiceAccount with a Role that allows one resource, and check both an allowed and a denied request;
- name the API server flags and kubelet settings that control anonymous access, authorization and network exposure;
- explain what the NodeRestriction admission plugin limits and what an audit policy records.

## How the module is laid out

You start with **How An API Request Is Checked**, which follows one request through authentication, authorization and admission, and tests what an anonymous caller may do. **A Narrow Workload Identity** then builds a ServiceAccount with one Role and uses its token from inside a Pod. **Hardening The Endpoint And The Kubelet** closes the module with the API server flags, the kubelet settings, network exposure, the NodeRestriction plugin and audit logging.

A lab follows the second and the third part, so you can practise each skill right after you read about it.

## Before you start

You should know the Kubernetes basics: Pods, Deployments, namespaces, Services and `kubectl exec`. Basic RBAC (role-based access control) helps too: a Role lists permissions, and a RoleBinding gives those permissions to a user, a group or a ServiceAccount.

## Your playground

Your playground is a virtual machine (VM) with a single-node Kubernetes v1.35 cluster that `kubeadm` created. You need a real node here, because some steps read the configuration files of the API server and the kubelet on the node itself. Run every command of the module in a shell on that VM. Open the shell from your own machine with this command, in every new terminal:

```sh
astrona ssh astro-ats-032-playground-030-01
```

You are the user `student`. You can run commands as root with `sudo`, which you need to read the configuration files on the node. `kubectl` already works and uses the `cluster-admin` role. The only node is called `controlplane`. It runs the control plane (the API server, etcd, the controller manager and the scheduler) and the example workloads.

The cluster starts with these objects:

| Namespace | Object | What it is |
| --- | --- | --- |
| `starfleet` | `probe` Deployment, two pods, labels `app: probe` and `release: probe` | A small Python web server on port 8080. You use its Python to send requests to the API |
| `starfleet` | `probe-code` ConfigMap | Holds `server.py`, the code of the `probe` web server |
| `starfleet` | `probe` Service | Port 80, forwards to port 8080 of the `probe` pods |
| `starfleet` | `shuttle` pod, label `app: shuttle` | A client pod with BusyBox tools |
| `outpost` | `drifter` pod, label `app: drifter` | A client pod with BusyBox tools, in another namespace |

All of these pods use the `default` ServiceAccount of their namespace. Launch your playground now, and keep it running while you read:

<!-- astrona:playground -->
