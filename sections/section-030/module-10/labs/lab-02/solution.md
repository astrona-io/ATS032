---
exam_objectives:
- Restrict access to Kubernetes API
---
# Harden The Kubelet On A Node: Solution

Connect to the lab first. Every command below runs in this shell on the node `controlplane`, as the user `student`:

```sh
astrona ssh astro-ats-032-lab-030-01-02
```

## See the problem

The API server can read the configuration that a kubelet is running with. It forwards the request to the `/configz` endpoint of the kubelet. The `jq` filter keeps only the four settings of this task:

```sh
kubectl get --raw /api/v1/nodes/controlplane/proxy/configz | jq '.kubeletconfig | {anonymous: .authentication.anonymous.enabled, webhook: .authentication.webhook.enabled, mode: .authorization.mode, readOnlyPort}'
```

```text
{
  "anonymous": true,
  "webhook": true,
  "mode": "AlwaysAllow",
  "readOnlyPort": 10255
}
```

The kubelet accepts anonymous requests, allows every request (`AlwaysAllow`) and serves the read-only port 10255. With these settings anyone who reaches the node can list its Pods. Send two requests with no credentials to the node's own address to see it:

```sh
node_ip=$(kubectl get node controlplane -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
curl -sk -o /dev/null -w '%{http_code}\n' https://$node_ip:10250/pods
curl -s -o /dev/null -w '%{http_code}\n' http://$node_ip:10255/pods
```

Both requests print `200`. The kubelet returned its full Pod list, including the API server and etcd Pods, to a caller it does not know.

## Change the kubelet configuration

The configuration file belongs to root, so edit it with `sudo`:

```sh
sudo vi /var/lib/kubelet/config.yaml
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

You can also delete the `readOnlyPort` line, because `0` is the default. With `anonymous.enabled: false` the kubelet refuses requests that carry no credentials. With `mode: Webhook` the kubelet sends a SubjectAccessReview to the API server for every request, and RBAC decides. Check the three lines before you go on:

```sh
sudo grep -n -A1 -E 'anonymous:|^authorization:|readOnlyPort' /var/lib/kubelet/config.yaml
```

```text
3:  anonymous:
4-    enabled: false
--
10:authorization:
11-  mode: Webhook
--
50:readOnlyPort: 0
```

The kubelet reads its configuration file only when it starts. Restart it and check that the service runs:

```sh
sudo systemctl restart kubelet
systemctl is-active kubelet
```

The second command prints `active`.

## Check the result

Wait until the node is `Ready`, then read the running configuration again:

```sh
kubectl wait --for=condition=Ready node/controlplane --timeout=120s
kubectl get --raw /api/v1/nodes/controlplane/proxy/configz | jq '.kubeletconfig | {anonymous: .authentication.anonymous.enabled, webhook: .authentication.webhook.enabled, mode: .authorization.mode, readOnlyPort}'
```

```text
node/controlplane condition met
{
  "anonymous": false,
  "webhook": true,
  "mode": "Webhook",
  "readOnlyPort": null
}
```

The kubelet leaves out `readOnlyPort` when it is `0`, so `jq` prints `null`. Send the same two requests again:

```sh
curl -sk -o /dev/null -w '%{http_code}\n' https://$node_ip:10250/pods
curl -s -o /dev/null -w '%{http_code}\n' http://$node_ip:10255/pods; echo "curl exit code: $?"
```

```text
401
000
curl exit code: 7
```

Port 10250 now returns `401`. The request to port 10255 prints `000` and `curl` exits with code 7, because no process listens on that port.

The API server still works with the kubelet, because it authenticates with its own client certificate and RBAC allows that identity. Read the logs of the Pod `probe`:

```sh
kubectl -n starfleet-032-030-01-02 logs probe
```

The command prints `probe started`.

## Common pitfalls

> [!WARNING]
> - **Editing the file but not restarting the kubelet.** The running kubelet keeps the old settings. Check with the `/configz` request.
> - **Editing without `sudo`.** The file belongs to root, so the editor cannot save it.
> - **Turning off webhook authentication.** The API server and other clients then cannot authenticate with tokens. Change only `anonymous`.
> - **Breaking the YAML indentation.** The kubelet then does not start and the node becomes `NotReady`. Read `sudo journalctl -u kubelet` on the node.
