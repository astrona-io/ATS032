# Summary

A cluster stays protected only while its Kubernetes version receives fixes, and only the newest three minor versions receive them. Upgrading is therefore a security control. An upgrade must follow the version skew rules. The API server is never older than another component, so the control plane goes first, one minor version at a time.

You empty a node before you upgrade it. `kubectl cordon` stops new Pods from landing on the node, `kubectl drain` evicts the running Pods, and `kubectl uncordon` returns the node to service. A drain stops at bare Pods, which no controller owns. A PodDisruptionBudget can hold the drain back so that enough replicas stay available. When no other node has room, evicted Pods wait as `Pending` until the node returns.

On a kubeadm cluster, you first switch the package repository to the next minor version and upgrade the `kubeadm` package. `kubeadm upgrade plan` shows the targets, and `kubeadm upgrade apply` upgrades the control-plane static Pods on the first control-plane node. Every other node uses `kubeadm upgrade node`. Then you drain each node, upgrade its `kubelet` and `kubectl` packages, run `systemctl daemon-reload`, restart the kubelet and uncordon the node.

The etcd snapshot that you take before the upgrade is the way back. After the upgrade, a short set of checks proves that the nodes, the API server and the application work on the new version.

Key facts to remember:

- `sudo etcdctl snapshot save` needs the endpoint and the certificate authority (CA) file, certificate and key from `/etc/kubernetes/pki/etcd/`.
- `etcdutl snapshot status` checks the file; in etcd 3.6, `etcdctl snapshot status` no longer exists and `ETCDCTL_API=3` is not needed.
- `etcdutl snapshot restore` writes a new data directory, and the etcd manifest must point at it.
- A snapshot holds every Secret, so keep it at mode `0600` and store it off the host.
- After the upgrade, check the node versions, `/readyz?verbose`, Pods that are not running, the certificate dates and one real application request.

<!-- astrona:playground:destroy -->
