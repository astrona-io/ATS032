---
exam_objectives:
- Restrict access to Kubernetes API
---
# Harden The Kubelet On A Worker Node: Solution

Connect to the lab first, so that `kubectl` talks to this lab's cluster and `$worker` names the worker node:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-030-01-02)"
worker="astro-ats-032-lab-030-01-02-worker"
control_plane="astro-ats-032-lab-030-01-02-control-plane"
```

## See the problem

The API server can read the configuration that a kubelet is running with. It forwards the request to the kubelet's `/configz` endpoint:

```sh
kubectl get --raw /api/v1/nodes/$worker/proxy/configz | python3 -m json.tool | grep -A3 -E '"anonymous"|"mode"|readOnlyPort'
```

The output shows `"enabled": true` for anonymous authentication, the mode `AlwaysAllow` and `"readOnlyPort": 10255`. With these settings anyone who reaches the node can list its Pods. Send a request with no credentials from the control plane node to see it:

```sh
worker_ip=$(kubectl get node $worker -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
podman exec $control_plane curl -sk -o /dev/null -w '%{http_code}\n' https://$worker_ip:10250/pods
podman exec $control_plane curl -s -o /dev/null -w '%{http_code}\n' http://$worker_ip:10255/pods
```

Both requests return `200`.

## Change the kubelet configuration

Open a shell on the worker node and edit `/var/lib/kubelet/config.yaml`:

```sh
podman exec -it $worker bash
vi /var/lib/kubelet/config.yaml
```

Set these three fields. Leave the other fields as they are, including `webhook.enabled: true` and the `x509.clientCAFile` line:

```yaml
authentication:
  anonymous:
    enabled: false
authorization:
  mode: Webhook
readOnlyPort: 0
```

You can also delete the `readOnlyPort` line, because `0` is the default. With `anonymous.enabled: false` the kubelet refuses requests that carry no credentials. With `mode: Webhook` the kubelet sends a SubjectAccessReview to the API server for every request, and RBAC decides.

The kubelet reads its configuration file only when it starts. Restart it, then leave the node shell:

```sh
systemctl restart kubelet
systemctl is-active kubelet
exit
```

## Check the result

Wait until the node is `Ready`, then send the same requests again:

```sh
kubectl wait --for=condition=Ready node/$worker --timeout=120s
podman exec $control_plane curl -sk -o /dev/null -w '%{http_code}\n' https://$worker_ip:10250/pods
podman exec $control_plane curl -s -o /dev/null -w '%{http_code}\n' http://$worker_ip:10255/pods
```

Port 10250 now returns `401`. The request to port 10255 prints `000` and `curl` exits with code 7, because no process listens on that port.

The API server still works with the kubelet, because it authenticates with its own client certificate. Read the logs of the Pod on the worker:

```sh
kubectl -n starfleet-032-030-01-02 logs probe
```

The command prints `probe started`.

## Common pitfalls

> [!WARNING]
> - **Editing the file but not restarting the kubelet.** The running kubelet keeps the old settings. Check with the `/configz` request.
> - **Turning off webhook authentication.** The API server and other clients then cannot authenticate with tokens. Change only `anonymous`.
> - **Breaking the YAML indentation.** The kubelet then does not start and the node becomes `NotReady`. Read `journalctl -u kubelet` on the node.
