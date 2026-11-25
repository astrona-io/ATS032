---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Summary

This module covered the patching that sits below Kubernetes, the proof that a maintenance window worked, and the limits of going back.

A node has an operating system, a kernel, a container runtime and the Kubernetes node packages. Only the last group is patched by the upgrade procedure. The others need the distribution's tools, and a kernel patch takes effect only after a reboot. The safe routine handles one node at a time: cordon and drain, patch, reboot if needed, uncordon and check. Replacing a node with one built from a newer image gives the same result. A reboot controller automates the routine and keeps to one node at a time. A drain stops at bare Pods, which have no controller to create them again, unless you force it. A restart of `containerd` gives the runtime a new process but leaves running containers alone; the drain is still needed in case the runtime does not come back. A window can leave a cordoned node or a custom taint, and uncordon does not remove a taint that a person added.

A post-upgrade check works from the bottom up. The nodes must be Ready and on the target version. The `/livez` and `/readyz` endpoints prove the API server. The system and application Pods must be running and placed as designed; the events of a Pending Pod name the taint, cordon or anti-affinity rule that blocks it. Every disruption budget must allow at least one disruption where the application has more than one replica. The metric of deprecated API requests shows what the next upgrade can break. A real request through a Service proves the application path.

Kubernetes has no downgrade. When an upgrade goes wrong, the team fixes forward if the control plane is healthy, and restores etcd from the pre-upgrade snapshot if the control plane or its data is damaged. A restore loses every change made after the snapshot. Snapshots must be recent, verified and stored off the host with the protection that Secrets need, and a restore drill proves that the procedure works. `etcdutl snapshot restore` writes only into a new, empty directory. On one control-plane node, the restore then changes only the `hostPath` of the etcd data volume in the static Pod manifest, and the flags `--bump-revision` and `--mark-compacted` make the watching controllers start again from a fresh list.

- Reboot after a kernel patch, and drain before the reboot.
- Remove every taint that the window added, not only the cordon.
- Run the same layered check after every window.
- Decide between fixing forward and restoring before the window starts.

Clean up the playground when you finish.

<!-- astrona:playground:destroy -->
