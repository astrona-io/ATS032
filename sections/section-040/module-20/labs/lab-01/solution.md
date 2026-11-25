---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Record A Cluster Version Inventory With Image Digests: Solution

Connect to the lab first, so that `kubectl` talks to this lab's cluster:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-040-02-01)"
```

The output below comes from one run of this lab. Your `probe` image and digest can differ, because the lab picks the `busybox` tag when it starts.

## Read the API server and the nodes

`kubectl version` asks the API server for its version. The client line shows your own `kubectl`, so only the server line counts:

```sh
kubectl version
```

```text
Server Version: v1.35.0
```

That output is shortened to the server line. The full `gitVersion` field is also in `kubectl get --raw /version`.

The kubelet and the container runtime report their versions in the node status. The kubelet writes them into `.status.nodeInfo` when it registers the node:

```sh
kubectl get nodes -o custom-columns=NAME:.metadata.name,KUBELET:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion
```

```text
NAME                                        KUBELET   RUNTIME
astro-ats-032-lab-040-02-01-control-plane   v1.35.0   containerd://2.2.0
astro-ats-032-lab-040-02-01-worker          v1.35.0   containerd://2.2.0
```

Record the runtime exactly as shown, with `containerd://`.

## Read the control plane components

etcd and CoreDNS are separate projects with their own version numbers. Their versions are in the image tags of their Pods:

```sh
kubectl -n kube-system get pods -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[*].image
```

The output is shortened to the two lines that matter here:

```text
coredns-7d764666f9-9kn2d                         registry.k8s.io/coredns/coredns:v1.13.1
etcd-astro-ats-032-lab-040-02-01-control-plane   registry.k8s.io/etcd:3.6.6-0
```

## Read the workload image and its digest

The Deployment holds the image as you wrote it. The Pod status holds what the container runtime really started:

```sh
kubectl -n starfleet-032-040-02-01 get deployment probe -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
kubectl -n starfleet-032-040-02-01 get pods -l app=probe -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].imageID}{"\n"}{end}'
```

```text
docker.io/library/busybox:1.36.1
probe-9b48f9976-hb8qj	sha256:b7c873bd97bdc9046fc894e0b216c8aef31e0db4c5b761fb53022e40577ab6c0
probe-9b48f9976-nd5th	sha256:b7c873bd97bdc9046fc894e0b216c8aef31e0db4c5b761fb53022e40577ab6c0
```

The lab loaded the image into the node without a pull, so `imageID` shows only `sha256:` and the digest. On a node that pulls from a registry, the field reads `docker.io/library/busybox@sha256:...`. Record only the `sha256:` part. Both Pods show the same digest, so they run the same image content.

## Write the inventory

Save this as `configmap-version-inventory.yaml`, with your own values:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: version-inventory
  namespace: starfleet-032-040-02-01
data:
  server-version: v1.35.0
  kubelet-control-plane: v1.35.0
  kubelet-worker: v1.35.0
  container-runtime: containerd://2.2.0
  etcd-image: registry.k8s.io/etcd:3.6.6-0
  coredns-image: registry.k8s.io/coredns/coredns:v1.13.1
  probe-image: docker.io/library/busybox:1.36.1
  probe-digest: sha256:b7c873bd97bdc9046fc894e0b216c8aef31e0db4c5b761fb53022e40577ab6c0
```

Apply it:

```sh
kubectl apply -f configmap-version-inventory.yaml
```

Then check the result:

```sh
kubectl -n starfleet-032-040-02-01 get configmap version-inventory -o yaml
```

The grader reads the same fields from the cluster on every run and compares them with your ConfigMap. The digest passes when it matches the `imageID` of a running `probe` Pod.
