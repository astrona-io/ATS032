---
exam_objectives:
- Restrict access to Kubernetes API
---
# Harden The Kubelet On A Node

Allow about 10 minutes for the tasks.

A security scan of the cluster reports that the kubelet on the node `controlplane` answers requests from anyone. The kubelet is the node agent that starts containers and serves its own HTTPS API on port 10250. Close that API again without breaking the node.

## Connect to the lab

The lab is a virtual machine (VM) with one Kubernetes node. Open a shell on it from your own machine:

```sh
astrona ssh astro-ats-032-lab-030-01-02
```

You are the user `student`. You can run commands as root with `sudo`, and `kubectl` already works for this cluster. The node is called `controlplane`. It is the only node, so it runs the control plane and the workload. The kubelet reads its configuration from `/var/lib/kubelet/config.yaml`, and systemd runs it as the service `kubelet`.

## Tasks

Change the kubelet configuration on the node `controlplane`:

1. Turn off anonymous authentication. Keep webhook token authentication on.
2. Set the authorization mode to `Webhook`.
3. Turn off the read-only port 10255.
4. Restart the kubelet so that it uses the new configuration.

After the change, an anonymous HTTPS request to port 10250 of the node must get `401 Unauthorized`, and port 10255 must refuse connections. The node must be `Ready`, and `kubectl logs` must still work for the Pod `probe` in the namespace `starfleet-032-030-01-02`.

## How the answer is checked

The grader runs three checks:

- The configuration that the running kubelet reports through the API server has anonymous authentication off, webhook authentication on, the authorization mode `Webhook` and no read-only port.
- An HTTPS request with no credentials to port 10250 of the node gets `401`, and a connection to port 10255 is refused.
- The node `controlplane` is `Ready` with that configuration, the Pod `probe` still runs on it, and `kubectl logs` prints its log line.
