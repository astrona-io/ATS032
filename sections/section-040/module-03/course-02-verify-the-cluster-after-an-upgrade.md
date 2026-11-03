---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Verify The Cluster After An Upgrade

After an upgrade or a patch window, the commands have succeeded and the cluster looks quiet. That is not proof. A node can stay cordoned, a Pod can wait for a place to run and a budget can block the next drain, all without an error message. This part gives a layered check that goes from the nodes up to a real request, so that each layer is proven before the next one is trusted.

## Why the order matters

A failure at a lower layer causes confusing failures above it. If a node is `NotReady`, Pods on it look broken. If the API server is not healthy, every `kubectl` answer is suspect. So the check starts at the bottom, and a failed layer stops the check until it is fixed.

The layers are: the nodes, the control plane, the system Pods, the application Pods, the disruption budgets, the use of deprecated APIs, and a request that goes through the whole path. Every layer has a command, and each command reads the cluster and changes nothing.

## Layer one and two: nodes and the API server

Every node must be `Ready`, with no `SchedulingDisabled` mark, and must show the target version. Then the API server must report that it is alive and ready. The endpoint `/livez` says whether the process is alive, and `/readyz` says whether it can serve requests. The `verbose` option lists each internal check.

<!-- astrona:playground:renew -->

```sh
kubectl get nodes -o wide
kubectl get --raw='/livez?verbose'
kubectl get --raw='/readyz?verbose'
```

Each check in the verbose output is listed with `ok`, and the last line says whether the check passed. A line without `ok` names the failing check. In a cluster with several control-plane nodes, run the check against each API server and not only against a load balancer.

## Layer three and four: system and application Pods

The system Pods in `kube-system` run DNS, the network plugin and the proxy. If they are not ready, application Pods fail in ways that look like application bugs. List every Pod that is not in the `Running` phase in any namespace. Then list the Pods of the application with the node of each:

```sh
kubectl get pods -A --field-selector=status.phase!=Running
kubectl -n starfleet get pods -l app=probe -o wide
```

The first command should show only finished Pods and nothing in the `Pending` or `Failed` phase. A Pod in the `Pending` phase has not been placed on a node yet. Describe it to read the reason in its events. The usual reasons after a window are a node that is still cordoned, a taint without a matching toleration, and a rule such as anti-affinity that has no node left to satisfy it. The second command shows whether the replicas are spread over different nodes as the specification requires.

## Layer five: disruption budgets

A budget that allows no disruption does not break anything today, but it blocks the next drain. After every window, read the **allowed disruptions** of each PodDisruptionBudget. This is the number of voluntary evictions the API server will permit now:

```sh
kubectl get pdb -A
```

The column `ALLOWED DISRUPTIONS` must be at least 1 for every budget that protects an application with more than one replica. A value of 0 has two common causes: the budget asks for as many Pods as exist, or fewer Pods are ready than the budget needs, so some Pods are missing. Fix the cause before you leave the window.

## Layer six: deprecated APIs

Kubernetes removes old API versions in later releases. A workload or a tool that still calls a removed version fails after the upgrade that removes it. The API server counts requests to deprecated APIs in a metric named `apiserver_requested_deprecated_apis`. Each series carries the API group, the version, the resource and the release in which the API will be removed.

```sh
kubectl get --raw /metrics | grep apiserver_requested_deprecated_apis
```

The command prints one line for each deprecated API that a client has called since the API server started. No output means that no client has called a deprecated API since the start, and the metric exists only after the first such call. Read the `removed_release` label, and migrate the caller before that release. Run the check before the next upgrade as well, because it tells you what the next upgrade can break.

## The last layer: a real request

The previous layers prove the platform. The last check proves the application through the same path that users take: a Service name, the cluster DNS, the network and a Pod. Send a request from a client Pod to the Service:

```sh
kubectl -n starfleet exec shuttle -- wget -q -T 3 -O- http://probe/
```

The answer is the text that `probe` returns, including its version. A timeout points to the network, DNS or the Service endpoints. When you check an application, test one request for each important path, not only one.

Also read the events that the cluster recorded during the window. Warnings in the namespace of the application often name the cause directly:

```sh
kubectl get events -A --field-selector type=Warning
```

An empty result is good. Old warnings from before the window can appear too, so read the timestamps.

You now have a layered check that finds the quiet failures of a window. If a check fails and the fix is not clear, the question is whether to go back, which is the subject of the next part.

## Common pitfalls

> [!WARNING]
> - **Checking only `kubectl get nodes`.** A healthy node list does not show Pending Pods, blocked budgets or a broken application.
> - **Stopping at a green API check.** The application path needs its own request.
> - **Ignoring a budget with zero allowed disruptions.** It blocks the next window.
> - **Reading the deprecated API metric only after the upgrade.** Read it before, so you can migrate the callers.
> - **Deleting a Pending Pod to make it go away.** The controller creates a new one that is Pending for the same reason.
