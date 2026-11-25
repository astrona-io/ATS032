# Dedicated Least-Privilege ServiceAccounts

A ServiceAccount is the identity of a workload inside one namespace. When a pod calls the Kubernetes API, the API server checks the ServiceAccount of the pod. Kubernetes gives permissions to that identity through RBAC (role-based access control), the system that decides which identity may do which action on which objects.

If many workloads share one ServiceAccount, they also share every permission it ever receives. A permission added for one application then reaches all the others. This module shows how to give each workload its own ServiceAccount, how to keep a new ServiceAccount free of permissions until a workload needs one, and how to clean up the `default` ServiceAccount that every namespace has.

Keep one sentence in mind for this module: **one workload, one ServiceAccount, and only the permissions that workload uses.** You move a Deployment to its own account, create an account with a single narrow rule, and test the result with permission checks. Then you remove a permission that someone gave to `default`.

## What you will learn

After this module, you can:

- create a ServiceAccount for one workload and assign it to a Deployment or a pod;
- explain why the ServiceAccount of a pod cannot be changed after the pod is created;
- write a Role with a minimal list of rules and bind it to one ServiceAccount with a RoleBinding;
- test what a ServiceAccount may do with `kubectl auth can-i` and `--as`;
- find and remove permissions on the `default` ServiceAccount and turn off its token mounting.

## How the module is laid out

You start with **One ServiceAccount For Each Workload**, which creates an account, assigns it to a Deployment and explains why a pod cannot change its account later. **Grant Only What The Workload Uses** then writes a Role with narrow rules, binds it to one account and tests it with `kubectl auth can-i`. **Clean Up The Default ServiceAccount** closes the module. It finds the bindings that name `default`, removes them and turns off token mounting for the account in every namespace you own.

A lab follows each part, so you can practise the skill right away.

## Before you start

You should know the Kubernetes basics: pods, namespaces, Deployments, YAML manifests and `kubectl exec`. You should also know that a pod receives a ServiceAccount token, and that `automountServiceAccountToken: false` stops the token from being mounted into the pod.

The commands run against a playground cluster. Your terminal must use the private kubeconfig of the playground. A kubeconfig is the file that holds the cluster address and the credentials for `kubectl`. Run these two commands once in every new terminal:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-020-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-020-02" || exit 1
```

The first command points `kubectl` at the playground. The second command stops if the current context is a different cluster.

## Your playground

Your playground is a `kind` cluster that runs Kubernetes 1.35, with one control-plane node and one worker node. Your own credentials have the `cluster-admin` role. The cluster already holds these objects:

| Namespace | Object | What it is |
| --- | --- | --- |
| `starfleet` | `probe` Deployment, two replicas, label `app: probe` | A small web server that listens on port 8080. It uses the `default` ServiceAccount |
| `starfleet` | `probe` Service | Port 80, forwards to port 8080 of the `probe` pods |
| `starfleet` | `probe-code` ConfigMap | Holds the program that the `probe` pods run |
| `starfleet` | `shuttle` pod, label `app: shuttle` | A client pod that uses the `default` ServiceAccount |
| `starfleet` | `pod-access` Role | Allows `get`, `list` and `watch` on pods |
| `starfleet` | `default-pod-access` RoleBinding | Gives the `pod-access` Role to the `default` ServiceAccount |
| `outpost` | `drifter` pod, label `app: drifter` | A client pod that uses the `default` ServiceAccount of `outpost` |

Start your playground now and keep it running while you read:

<!-- astrona:playground -->
