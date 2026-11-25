# Restrict Access To The Kubernetes API

The API server is the front door of the cluster. Every `kubectl` command, every controller and every pod that talks to Kubernetes goes through it. If the door is set up badly, a stranger can read cluster data, or a valid user can create an object that harms the cluster.

Every request to the API server passes three checks. Authentication finds out who is calling. Authorization decides whether that caller may do the action. Admission control looks at the content of a write and can reject it. A weak setting in any of the three opens the cluster. In this section, you follow a request through the three checks and learn how to make each one strict.

## What you will learn

The section moves from the path of one request to the rules that guard it:

- **Restrict Access To The Kubernetes API.** The three checks, a narrow identity for a workload, and the API server and kubelet settings that limit who can reach and use the API.
- **Authentication, Anonymous Access And Authorization Modes.** How the API server identifies a caller, what an anonymous caller can reach and which bindings open it, the authorization modes, and impersonation.
- **Admission Control For API Writes.** Pod Security admission, ValidatingAdmissionPolicy, and admission webhooks with their failure policy.

## How this section works

Each module has its own playground. Some modules use a virtual machine (VM) with a one-node Kubernetes v1.35 cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine, so you can read and change the real API server and kubelet settings. Others use a private `kind` cluster with Kubernetes v1.35. Start the playground from the first page of the module and keep it running while you read.

When a page teaches a skill you can be graded on, a lab comes right after it. A lab gives you a short task in a fresh cluster and checks your result. Each module ends with a summary and a short knowledge check.

## By the end of this section

You will be able to:

- name the three checks and the status code that each one returns when it fails;
- test anonymous access and token access from a pod;
- give a workload an identity that allows one resource only;
- name the API server and kubelet settings that harden access to the API;
- name the authentication methods, and explain why an invalid token returns 401 and does not fall back to anonymous access;
- find and remove a binding that gives anonymous callers access to cluster data;
- name the authorization modes, and say why `AlwaysAllow` must never be used;
- enforce the Pod Security Standards with namespace labels;
- write a ValidatingAdmissionPolicy and a binding that reject a forbidden object;
- choose a webhook failure policy, and explain the risk of `Ignore`.
