---
exam_objectives:
- Restrict access to Kubernetes API
---
# Remove Static Token Authentication From The API Server: Solution

Open a shell on the lab VM from your own machine. All later commands run in that shell as the user `student`:

```sh
astrona ssh astro-ats-032-lab-030-02-02
```

## Find the flag and the file

The kubelet on the node `controlplane` runs the API server from a static Pod manifest. Read the flag in the running Pod:

```sh
kubectl -n kube-system get pod -l component=kube-apiserver -o yaml | grep token-auth-file
```

The output is one line:

```text
      - --token-auth-file=/etc/kubernetes/pki/legacy-tokens.csv
```

Only root can read files in `/etc/kubernetes/pki`, so look at the token file with `sudo`:

```sh
sudo cat /etc/kubernetes/pki/legacy-tokens.csv
```

The file has one line: the token, the user `legacy-admin`, a user ID and the group `system:masters`. The token itself is a random value, so it is shown here as `<TOKEN>`:

```text
<TOKEN>,legacy-admin,legacy-admin-uid,"system:masters"
```

Members of `system:masters` pass every authorization check, so whoever holds this token is a full administrator. Keep the token in a shell variable, and prove that it works before you remove it:

```sh
token=$(sudo cut -d, -f1 /etc/kubernetes/pki/legacy-tokens.csv)
curl -sk -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $token" https://127.0.0.1:6443/api
```

The request returns `200`.

## Remove the flag

Copy the manifest to a directory outside `/etc/kubernetes/manifests` first. The kubelet runs every manifest in that directory, so a backup kept there starts a second API server. Then delete the line with the flag:

```sh
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak
sudo sed -i '/- --token-auth-file=/d' /etc/kubernetes/manifests/kube-apiserver.yaml
sudo grep -c token-auth-file /etc/kubernetes/manifests/kube-apiserver.yaml
```

`grep -c` prints `0`. You can also make the change with `sudo vi`. Delete the whole list item, including the leading `- `.

The kubelet sees the changed file, stops the old API server container and starts a new one. During that time `kubectl` and `curl` cannot connect.

## Delete the token file

The flag is gone, so the file has no use. Delete it, because it still holds a working administrator token:

```sh
sudo rm /etc/kubernetes/pki/legacy-tokens.csv
```

## Check the result

Send the same request again, and repeat it every few seconds until the restarted API server answers:

```sh
curl -sk -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $token" https://127.0.0.1:6443/api
```

In the test run, the first try right after the edit still returned `200` from the old API server. The next tries returned `000`, which means `curl` got no HTTP response because no API server was listening. After about 45 seconds the request returned `401`. No authentication method accepts the token any more, and a credential that nobody accepts is always rejected, never treated as anonymous.

Check that the API server Pod is back and ready:

```sh
kubectl -n kube-system get pod -l component=kube-apiserver
kubectl get --raw /readyz
```

The Pod is Ready, and `/readyz` prints `ok`. Your `AGE` differs:

```text
NAME                          READY   STATUS    RESTARTS   AGE
kube-apiserver-controlplane   1/1     Running   0          19s
ok
```

## Common pitfalls

> [!WARNING]
> - **Keeping a backup in `/etc/kubernetes/manifests`.** The kubelet starts it as a second API server.
> - **Removing the flag but keeping the file.** Anybody who can read the file still has an administrator token for the next time someone turns the flag on.
> - **Testing too early.** The old API server keeps answering for a short time after the edit. Wait until the request with the token returns `401`.
