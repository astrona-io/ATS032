---
exam_objectives:
- Restrict access to Kubernetes API
---
# Remove Static Token Authentication From The API Server: Solution

Connect to the lab first, so that `kubectl` talks to this lab's cluster:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-030-02-02)"
control_plane="astro-ats-032-lab-030-02-02-control-plane"
```

## Find the flag and the file

The kubelet on the control plane node runs the API server from a static Pod manifest. Read the flag in the running Pod:

```sh
kubectl -n kube-system get pod -l component=kube-apiserver -o yaml | grep token-auth-file
```

The line shows `--token-auth-file=/etc/kubernetes/pki/legacy-tokens.csv`. Open a shell on the control plane node and look at the file:

```sh
podman exec -it $control_plane bash
cat /etc/kubernetes/pki/legacy-tokens.csv
```

The file has one line: the token, the user `legacy-admin`, a user ID and the group `system:masters`. Members of `system:masters` pass every authorization check, so whoever holds this token is a full administrator. You can prove that the token works before you remove it:

```sh
token=$(cut -d, -f1 /etc/kubernetes/pki/legacy-tokens.csv)
curl -sk -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $token" https://127.0.0.1:6443/api
```

The request returns `200`.

## Remove the flag

Copy the manifest to a directory outside `/etc/kubernetes/manifests` first. The kubelet runs every manifest in that directory, so a backup kept there starts a second API server. Then delete the line with the flag:

```sh
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak
sed -i '/- --token-auth-file=/d' /etc/kubernetes/manifests/kube-apiserver.yaml
grep -c token-auth-file /etc/kubernetes/manifests/kube-apiserver.yaml
```

`grep -c` prints `0`. You can also make the change with `vi`; delete the whole list item, including the leading `- `.

The kubelet sees the changed file, stops the old API server container and starts a new one. This takes about a minute. During that time `kubectl` cannot connect.

## Delete the token file

The flag is gone, so the file has no use. Delete it, because it still holds a working administrator token:

```sh
rm /etc/kubernetes/pki/legacy-tokens.csv
```

## Check the result

Still on the node, send the same request again. Repeat it every few seconds until the restarted API server answers:

```sh
curl -sk -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $token" https://127.0.0.1:6443/api
exit
```

The request now returns `401`. No authentication method accepts the token, and a credential that nobody accepts is always rejected, never treated as anonymous.

From your machine, check that the API server Pod is back and ready:

```sh
kubectl -n kube-system get pod -l component=kube-apiserver
kubectl get --raw /readyz
```

The Pod shows `1/1` and `Running`, and `/readyz` prints `ok`.

## Common pitfalls

> [!WARNING]
> - **Keeping a backup in `/etc/kubernetes/manifests`.** The kubelet starts it as a second API server.
> - **Removing the flag but keeping the file.** Anybody who can read the file still has an administrator token for the next time someone turns the flag on.
> - **Testing too early.** The old API server keeps answering for a short time after the edit. Wait until the request with the token returns `401`.
