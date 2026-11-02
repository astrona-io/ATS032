---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Summary

This module covered how to keep a cluster on a supported version and how to do it without losing availability or state.

- Only the newest three minor versions receive fixes. An unsupported cluster stays exposed to known vulnerabilities.
- Upgrade one minor version at a time. The API server must not be older than any other component. The kubelet may be up to three minor versions older, the controller manager and scheduler one, and `kubectl` may differ by one in either direction.
- `kubectl cordon` stops scheduling, `kubectl drain` evicts Pods, and `kubectl uncordon` returns the node. Use `--ignore-daemonsets` and a `--timeout`, and do not use `--force` on bare Pods.
- A PodDisruptionBudget limits voluntary evictions through `minAvailable` or `maxUnavailable`. It needs enough replicas to be useful, and it does not stop node failures.
- On kubeadm: install the new `kubeadm`, run `kubeadm upgrade plan`, run `kubeadm upgrade apply` on the first control-plane node, run `kubeadm upgrade node` on every other node, then drain, upgrade `kubelet` and `kubectl`, run `systemctl daemon-reload` and restart the kubelet, and uncordon.
- Take an etcd snapshot with `etcdctl snapshot save` and the three certificate flags before the upgrade, check it with `etcdutl snapshot status`, and protect it because it contains all Secrets.
- After the upgrade, check `kubectl get nodes`, the `/readyz?verbose` endpoint, the system Pods and a real application request.

Clean up the playground when you finish.

<!-- astrona:playground:destroy -->
