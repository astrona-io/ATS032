---
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Restart The Container Runtime On A Drained Node

Allow about 10 minutes for the tasks.

A patched `containerd` package is already installed on the node of the `starfleet` cluster. The new binary only runs after the service restarts. The node is cordoned for the maintenance window, and both `probe` Pods still run on it.

## Connect to the lab

The lab is a virtual machine (VM) with one Kubernetes node. Open a shell on it from your own machine:

```sh
astrona ssh astro-ats-032-lab-040-03-02
```

You are the user `student`. You can run commands as root with `sudo`, and `kubectl` already works for this cluster. The node is called `controlplane`. It is the only node, so it is both the control plane and the node that runs the workload. `containerd` is the container runtime: the service that starts and stops the containers of every Pod on the node. `systemctl` manages it as the `containerd` service.

## Tasks

The Deployment `probe` in the namespace `starfleet-032-040-03-02` has two replicas.

1. Drain the node `controlplane`, so that both `probe` Pods that run on it now are evicted.
2. Restart the `containerd` service on the node. It must be `active` afterwards.
3. Make the node Ready and schedulable again, so that two new `probe` Pods run and are available.

Do not delete the Deployment, the namespace or the ConfigMap `maintenance-baseline`, and do not reboot the VM.

## How the answer is checked

The grader runs three checks:

- The `containerd` service is `active`, and it started again after the lab began.
- None of the `probe` Pods from the start of the lab remains, and the Deployment `probe` has two available replicas.
- The node `controlplane` is Ready and not cordoned.

The grader checks the end state, so it cannot prove that you drained the node before the restart.
