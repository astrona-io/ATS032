---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Run A Node Patch Window End To End Solution

Use a host shell with this lab's private kubeconfig. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool. This environment is separate from the ungraded playground.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-040-capstone-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-040-capstone-01" || exit 1
```

## Inspect and explain

Look at what stops a drain before you run it.

```sh
kubectl get nodes
kubectl -n starfleet get pods -l app=probe -o wide
kubectl -n starfleet get pdb probe
kubectl get pods -A -o wide --field-selector spec.nodeName=astro-ats-032-lab-040-capstone-01-worker
```

The budget shows `ALLOWED DISRUPTIONS` of `0`, so the eviction of the `probe` Pod would be refused. The Pod list for the first worker shows `drifter`, which has no controller, so the drain would refuse it too. Both causes must be fixed without `--force`.

## Fix the budget

Save this as `poddisruptionbudget-probe.yaml`:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: probe
  namespace: starfleet
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app: probe
```

Apply it:

```sh
kubectl apply -f poddisruptionbudget-probe.yaml
```

## Move the bare Pod

Nothing recreates a bare Pod, so delete it and create it again on the second worker. The first worker is cordoned, so the node selector must name the second worker. Save this as `pod-drifter.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: drifter
  namespace: outpost
  labels:
    app: drifter
spec:
  containers:
  - name: client
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
  restartPolicy: Never
  nodeSelector:
    kubernetes.io/hostname: astro-ats-032-lab-040-capstone-01-worker2
```

Delete the old Pod and apply the file:

```sh
kubectl -n outpost delete pod drifter
kubectl apply -f pod-drifter.yaml
kubectl -n outpost wait --for=condition=Ready pod/drifter --timeout=120s
```

## Drain and mark the node

```sh
kubectl drain astro-ats-032-lab-040-capstone-01-worker --ignore-daemonsets --timeout=180s
kubectl label node astro-ats-032-lab-040-capstone-01-worker patch-status=done
```

The drain evicts the `probe` Pod. Its replacement stays Pending, because the Deployment does not allow a second replica on the second worker and the first worker is still cordoned. This is expected until you return the node.

## Record the versions

Read the values, then fill in the file. The first command prints the API server version. The next two print the kubelet and runtime versions of the first worker. The last prints the image of the Deployment.

```sh
kubectl get --raw /version
kubectl get node astro-ats-032-lab-040-capstone-01-worker -o jsonpath='{.status.nodeInfo.kubeletVersion}{"\n"}{.status.nodeInfo.containerRuntimeVersion}{"\n"}'
kubectl -n starfleet get deployment probe -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

Replace the four placeholders. Save this as `configmap-version-inventory.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: version-inventory
  namespace: starfleet
data:
  server-version: <SERVER_VERSION>
  kubelet-worker: <KUBELET_WORKER>
  container-runtime-worker: <CONTAINER_RUNTIME_WORKER>
  probe-image: <PROBE_IMAGE>
```

Apply it:

```sh
kubectl apply -f configmap-version-inventory.yaml
```

## Return the node to service

```sh
kubectl uncordon astro-ats-032-lab-040-capstone-01-worker
kubectl taint nodes astro-ats-032-lab-040-capstone-01-worker maintenance=patching:NoSchedule-
kubectl -n starfleet rollout status deployment/probe --timeout=180s
```

## Verify the result

```sh
kubectl get nodes
kubectl -n starfleet get pods -l app=probe -o wide
kubectl -n starfleet get pdb probe
kubectl -n outpost get pod drifter -o wide
kubectl -n starfleet exec shuttle -- wget -q -T 3 -O- http://probe/
```

Both `probe` Pods run on different nodes, the budget allows one disruption, and the request returns the `probe` response. After recording the result, remove this independent lab with `astrona destroy ats-032-lab-040-capstone-01`.

## Common pitfalls

> [!WARNING]
> - **Using `--force` to get past `drifter`.** The Pod would be deleted and not recreated. Move it yourself.
> - **Changing the budget after the drain started.** Fix it first; the drain only waits until its timeout.
> - **Running `kubectl uncordon` and forgetting the taint.** The replacement `probe` Pod stays Pending.
> - **Typing versions from memory.** The grader compares them with the live cluster.
