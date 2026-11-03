---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Summary

This module covered the patching that sits below Kubernetes, the proof that a maintenance window worked, and the limits of going back.

A node has an operating system, a kernel, a container runtime and the Kubernetes node packages. Only the last group is patched by the upgrade procedure. The others need the distribution's tools, and a kernel patch takes effect only after a reboot. The safe routine handles one node at a time: cordon and drain, patch, reboot if needed, uncordon and check. Replacing a node with one built from a newer image gives the same result. A reboot controller automates the routine and keeps to one node at a time. A window can leave a cordoned node or a custom taint, and uncordon does not remove a taint that a person added.

A post-upgrade check works from the bottom up. The nodes must be Ready and on the target version. The `/livez` and `/readyz` endpoints prove the API server. The system and application Pods must be running and placed as designed. Every disruption budget must allow at least one disruption where the application has more than one replica. The metric of deprecated API requests shows what the next upgrade can break. A real request through a Service proves the application path.

Kubernetes has no downgrade. When an upgrade goes wrong, the team fixes forward if the control plane is healthy, and restores etcd from the pre-upgrade snapshot if the control plane or its data is damaged. A restore loses every change made after the snapshot. Snapshots must be recent, verified and stored off the host with the protection that Secrets need, and a restore drill on a spare host proves that the procedure works.

- Reboot after a kernel patch, and drain before the reboot.
- Remove every taint that the window added, not only the cordon.
- Run the same layered check after every window.
- Decide between fixing forward and restoring before the window starts.

Clean up the playground when you finish.

<!-- astrona:playground:destroy -->
