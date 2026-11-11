---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Record The Version Inventory And Patch Waves Solution

Use a host shell with the private kubeconfig for this independent kind environment.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-040-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-040-02-01" || exit 1
```

## Read the versions

The API server version comes from the `/version` endpoint. The node fields come from `status.nodeInfo` of each node. The images come from the workload specifications.

```sh
kubectl get --raw /version
kubectl get nodes -o custom-columns=NAME:.metadata.name,KUBELET:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion
kubectl -n starfleet-032-040-02-01 get deployment probe -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl -n outpost-032-040-02-01 get pod drifter -o jsonpath='{.spec.containers[0].image}{"\n"}'
```

Write down the `gitVersion` value, the kubelet version of each node, the runtime of the control-plane node and the two image names.

## Record them

Replace each placeholder in the file below with the value you read. Save this as `configmap-version-inventory.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: version-inventory
  namespace: starfleet-032-040-02-01
data:
  server-version: <SERVER_VERSION>
  kubelet-control-plane: <KUBELET_CONTROL_PLANE>
  kubelet-worker: <KUBELET_WORKER>
  kubelet-worker2: <KUBELET_WORKER2>
  container-runtime: <CONTAINER_RUNTIME>
  probe-image: <PROBE_IMAGE>
  client-image: <CLIENT_IMAGE>
```

Apply it:

```sh
kubectl apply -f configmap-version-inventory.yaml
```

## Label the patch waves

The control plane goes first, the first worker next, and the second worker last.

```sh
kubectl label node astro-ats-032-lab-040-02-01-control-plane patch-wave=1
kubectl label node astro-ats-032-lab-040-02-01-worker patch-wave=2
kubectl label node astro-ats-032-lab-040-02-01-worker2 patch-wave=3
```

## Verify the result

Print the ConfigMap and the labels, and compare the values with the live cluster once more.

```sh
kubectl -n starfleet-032-040-02-01 get configmap version-inventory -o yaml
kubectl get nodes -L patch-wave
```

After recording your result, remove the independent lab with `astrona destroy ats-032-lab-040-02-01`.

## Common pitfalls

> [!WARNING]
> - **Typing a version from memory.** Read it from the cluster; the grader compares with the live values.
> - **Using the image tag of `etcd` or `coredns` as the Kubernetes version.** The API server version comes from `/version`.
> - **Putting the second worker in an early wave.** It runs bare client Pods that a drain cannot move.
> - **Leaving a placeholder such as `<SERVER_VERSION>` in the file.** Replace every one before you apply.
