---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Triage Vulnerability Records And Label Patch Waves: Solution

Connect to the lab first, so that `kubectl` talks to this lab's cluster:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-040-02-02)"
```

The output below comes from one run of this lab. Your records and your `busybox` tag differ, because the lab creates them when it starts. Work through your own values the same way.

## Read the records

```sh
kubectl -n starfleet-032-040-02-02 get configmap advisory-feed -o jsonpath='{.data.records}'
```

```text
ID             COMPONENT  INTRODUCED  FIXED     SEVERITY
ADV-2026-9226  kubelet    1.35.1      1.35.4    Critical
ADV-2026-7613  coredns    1.12.0      1.13.1    Medium
ADV-2026-5820  busybox    1.36.0      1.37.0    High
ADV-2026-7173  etcd       3.6.1       3.6.7     Low
ADV-2026-7457  coredns    1.12.0      1.13.1    High
ADV-2026-7452  kubelet    1.35.0      1.35.2    Critical
ADV-2026-2491  busybox    1.37.0      1.37.3    Critical
ADV-2026-7662  etcd       3.6.7       3.6.9     Medium
```

## Read the running versions

Each component reports its version in a different place. The kubelet writes its version into the node status. The `etcd` and CoreDNS versions are the tags of their images, and the `busybox` version is the tag in the Deployment:

```sh
kubectl get nodes -o custom-columns=NAME:.metadata.name,KUBELET:.status.nodeInfo.kubeletVersion
kubectl -n kube-system get pods -l component=etcd -o jsonpath='{.items[0].spec.containers[0].image}'; echo
kubectl -n kube-system get pods -l k8s-app=kube-dns -o jsonpath='{.items[0].spec.containers[0].image}'; echo
kubectl -n starfleet-032-040-02-02 get deployment probe -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
```

```text
NAME                                        KUBELET
astro-ats-032-lab-040-02-02-control-plane   v1.35.0
astro-ats-032-lab-040-02-02-worker          v1.35.0
registry.k8s.io/etcd:3.6.6-0
registry.k8s.io/coredns/coredns:v1.13.1
docker.io/library/busybox:1.37.0
```

So the running versions are kubelet `1.35.0`, etcd `3.6.6`, CoreDNS `1.13.1` and busybox `1.37.0`.

## Apply the rule to each record

A record applies when INTRODUCED ≤ running < FIXED. Compare the numbers part by part, from left to right, so `1.35.0` is lower than `1.35.1`. In this run:

| ID | Running | Range | Applies |
| --- | --- | --- | --- |
| ADV-2026-9226 | kubelet 1.35.0 | 1.35.1 to 1.35.4 | no, introduced later |
| ADV-2026-7613 | coredns 1.13.1 | 1.12.0 to 1.13.1 | no, 1.13.1 is the fixed version |
| ADV-2026-5820 | busybox 1.37.0 | 1.36.0 to 1.37.0 | no, 1.37.0 is the fixed version |
| ADV-2026-7173 | etcd 3.6.6 | 3.6.1 to 3.6.7 | yes |
| ADV-2026-7457 | coredns 1.13.1 | 1.12.0 to 1.13.1 | no, 1.13.1 is the fixed version |
| ADV-2026-7452 | kubelet 1.35.0 | 1.35.0 to 1.35.2 | yes |
| ADV-2026-2491 | busybox 1.37.0 | 1.37.0 to 1.37.3 | yes |
| ADV-2026-7662 | etcd 3.6.6 | 3.6.7 to 3.6.9 | no, introduced later |

The edges are where mistakes happen. A cluster that runs exactly the FIXED version already has the fix. A cluster that runs exactly the INTRODUCED version has the flaw.

## Record the result

Save this as `configmap-triage.yaml`, with your own IDs:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: triage
  namespace: starfleet-032-040-02-02
data:
  affected: ADV-2026-7173 ADV-2026-7452 ADV-2026-2491
```

Apply it:

```sh
kubectl apply -f configmap-triage.yaml
```

## Label the patch waves

The control plane goes first, because a kubelet must never be newer than the API server. The worker follows in wave 2:

```sh
kubectl label node astro-ats-032-lab-040-02-02-control-plane patch-wave=1
kubectl label node astro-ats-032-lab-040-02-02-worker patch-wave=2
kubectl get nodes -L patch-wave
```

```text
NAME                                        STATUS   ROLES           AGE   VERSION   PATCH-WAVE
astro-ats-032-lab-040-02-02-control-plane   Ready    control-plane   41s   v1.35.0   1
astro-ats-032-lab-040-02-02-worker          Ready    <none>          26s   v1.35.0   2
```

The grader reads the records and the running versions again on every run, applies the same rule and compares the result with your list.
