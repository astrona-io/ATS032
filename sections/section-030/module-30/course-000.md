# Admission Control For API Writes

A request can come from a known caller and use an allowed verb, and still be harmful. For example, a user who may create Pods can create a Pod that mounts the file system of the node. Authorization cannot see this problem, because it only looks at who sends the request and what the request does. It never looks at the content of the object.

Admission control is the third check of the Kubernetes API server, after authentication and authorization. It is the only check that reads the object that a write request carries. An admission controller is a piece of code in the API server that reads a write request and then rejects it, accepts it or changes the object in it.

Keep one sentence in mind for this module: **admission runs after authorization, applies to every caller including `cluster-admin`, and rejects or changes the content of a write.** In the module you turn on the built-in Pod Security admission for a namespace. You write a rule in the Common Expression Language (CEL) as a ValidatingAdmissionPolicy. You also see what an admission webhook does when its service is down.

## What you will learn

After this module, you can:

- say where admission sits in the request path, which requests it sees and why `cluster-admin` is not exempt;
- name the three Pod Security Standards and the three modes, and set them with namespace labels;
- write a ValidatingAdmissionPolicy with a CEL expression, and a binding that limits it to one namespace;
- choose between the validation actions `Deny`, `Warn` and `Audit`;
- explain `failurePolicy`, the selectors of a webhook and the risk of a rule that fails open.

## How the module is laid out

You start with **Pod Security Admission**, which enforces the Pod Security Standards with labels on a namespace. **ValidatingAdmissionPolicy With CEL** then shows how to write your own rule that runs inside the API server. **Admission Webhooks And Failure Policy** closes the module with calls to an external service, and with the setting that decides what happens when such a call fails.

A lab follows each part, so you can practise the skill right away.

## Before you start

You should know the Kubernetes basics: Pods, Services, ConfigMaps, namespaces and labels. It also helps to know that role-based access control (RBAC) authorizes a request before admission runs.

## Your playground

The commands run against a playground cluster. Your terminal must use the private kubeconfig of the playground. A kubeconfig is the file that holds the cluster address and the credentials for `kubectl`. Run these two commands once in every new terminal:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-030-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-030-03" || exit 1
```

The first command points `kubectl` at the playground. The second command stops if the current context is not the playground cluster.

The playground is a `kind` cluster that runs Kubernetes 1.35, with one control-plane node and one worker node. Your own credentials have the `cluster-admin` role, and admission applies to them as well. The cluster starts with these objects:

| Namespace | Object | What it is |
| --- | --- | --- |
| `starfleet` | `probe` Deployment, two pods, label `app: probe` | A small Python web server that listens on port 8080 |
| `starfleet` | `probe` Service | Port 80, forwards to port 8080 of the `probe` pods |
| `starfleet` | `probe-code` ConfigMap | The code of the `probe` web server |
| `starfleet` | `shuttle` pod, label `app: shuttle` | A client pod with BusyBox tools |
| `outpost` | `drifter` pod, label `app: drifter` | A client pod with BusyBox tools, in another namespace |

No Pod Security label, admission policy or webhook configuration applies to either namespace yet.

Launch your playground now, and keep it running while you read:

<!-- astrona:playground -->
