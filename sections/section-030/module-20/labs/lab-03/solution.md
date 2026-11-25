---
exam_objectives:
- Restrict access to Kubernetes API
- Use Role Based Access Controls to minimize exposure
---
# Remove AlwaysAllow And Narrow Impersonation Rights: Solution

Open a shell on the lab VM from your own machine. All later commands run in that shell as the user `student`:

```sh
astrona ssh astro-ats-032-lab-030-02-03
```

## See the problem

The authorizers decide whether an authenticated request may go ahead. The API server asks them in the order of `--authorization-mode`, and the first one that allows the request wins. Ask the authorizers about a user that has no RBAC rules at all:

```sh
kubectl auth can-i list secrets -n kube-system --as=nobody
```

The command prints `yes`. RBAC has no rule for `nobody`, so the `yes` comes from `AlwaysAllow` at the end of the list.

`AlwaysAllow` has one more effect. The API server turns anonymous authentication off when `AlwaysAllow` is in the list, and its log says `AnonymousAuth is not allowed with the AlwaysAllow authorizer`. A request without credentials therefore gets `401`, but every authenticated user, including any ServiceAccount, may do everything. The kubelet's health probes of the API server are anonymous HTTPS requests. With `AlwaysAllow` they get `401`, and the Pod never becomes Ready. This lab therefore changed the probes to TCP checks, which only open a connection to the port:

```sh
sudo grep -A3 -e livenessProbe -e readinessProbe -e startupProbe /etc/kubernetes/manifests/kube-apiserver.yaml
```

Each probe shows `tcpSocket` instead of `httpGet`:

```text
    livenessProbe:
      failureThreshold: 8
      tcpSocket:
        host: 10.0.2.15
--
    readinessProbe:
      failureThreshold: 3
      tcpSocket:
        host: 10.0.2.15
--
    startupProbe:
      failureThreshold: 24
      tcpSocket:
        host: 10.0.2.15
```

Leave the probes as they are.

## Fix the authorization modes

Only root can change the manifest, so every command on it uses `sudo`. Copy the manifest to a directory outside `/etc/kubernetes/manifests` first, because the kubelet runs every manifest in that directory. Then set the flag back to `Node,RBAC`:

```sh
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak
sudo grep authorization-mode /etc/kubernetes/manifests/kube-apiserver.yaml
sudo sed -i 's/--authorization-mode=Node,RBAC,AlwaysAllow/--authorization-mode=Node,RBAC/' /etc/kubernetes/manifests/kube-apiserver.yaml
sudo grep authorization-mode /etc/kubernetes/manifests/kube-apiserver.yaml
```

The first `grep` shows `    - --authorization-mode=Node,RBAC,AlwaysAllow`, and the second shows `    - --authorization-mode=Node,RBAC`. The kubelet sees the changed file and starts a new API server container. During that time `kubectl` cannot connect, and it prints `The connection to the server 10.0.2.15:6443 was refused - did you specify the right host or port?`. In the test run this lasted about 40 seconds.

Repeat the same question every few seconds until the API server answers:

```sh
kubectl auth can-i list secrets -n kube-system --as=nobody
kubectl get --raw /readyz
```

The first command now prints `no`, and `/readyz` prints `ok`.

## Read the impersonation grant

The verb `impersonate` lets a caller send requests as another identity. Look at what the group `helpdesk` may impersonate today:

```sh
kubectl get clusterrole helpdesk-impersonate -o yaml
kubectl auth can-i impersonate groups/system:masters --as=helpdesk-user --as-group=helpdesk
```

The `rules` part of the ClusterRole is:

```text
rules:
- apiGroups:
  - ""
  resources:
  - users
  - groups
  - serviceaccounts
  verbs:
  - impersonate
```

The ClusterRole allows `impersonate` on `users`, `groups` and `serviceaccounts` with no `resourceNames`. The `can-i` command prints `yes`: a member of `helpdesk` can act as a member of `system:masters`, which is a full administrator.

## Narrow the ClusterRole and the binding

A ClusterRole bound with a RoleBinding gives its rules only inside the namespace of the RoleBinding. ServiceAccounts live in namespaces, so a RoleBinding in `starfleet-032-030-02-03` limits the grant to ServiceAccounts there. `resourceNames` limits it to one name.

Save this as `clusterrole-helpdesk-impersonate.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: helpdesk-impersonate
rules:
- apiGroups: [""]
  resources: ["serviceaccounts"]
  resourceNames: ["probe"]
  verbs: ["impersonate"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: helpdesk-impersonate
  namespace: starfleet-032-030-02-03
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: helpdesk-impersonate
subjects:
- kind: Group
  name: helpdesk
  apiGroup: rbac.authorization.k8s.io
```

Apply it, and delete the old ClusterRoleBinding:

```sh
kubectl apply -f clusterrole-helpdesk-impersonate.yaml
kubectl delete clusterrolebinding helpdesk-impersonate
```

The output is:

```text
clusterrole.rbac.authorization.k8s.io/helpdesk-impersonate configured
rolebinding.rbac.authorization.k8s.io/helpdesk-impersonate created
clusterrolebinding.rbac.authorization.k8s.io "helpdesk-impersonate" deleted
```

## Check the result

Ask the authorizers about each identity that a member of `helpdesk` might try to use:

```sh
kubectl auth can-i impersonate serviceaccounts/probe -n starfleet-032-030-02-03 --as=helpdesk-user --as-group=helpdesk
kubectl auth can-i impersonate serviceaccounts/probe -n outpost-032-030-02-03 --as=helpdesk-user --as-group=helpdesk
kubectl auth can-i impersonate serviceaccounts/default -n starfleet-032-030-02-03 --as=helpdesk-user --as-group=helpdesk
kubectl auth can-i impersonate groups/system:masters --as=helpdesk-user --as-group=helpdesk
```

The first command prints `yes`. The other three print `no`.

## Common pitfalls

> [!WARNING]
> - **Testing too early.** The old API server keeps answering for a short time after the edit. Wait until `can-i` for `nobody` prints `no`.
> - **Keeping the ClusterRoleBinding.** A ClusterRoleBinding grants the rules in every namespace, so `probe` in `outpost-032-030-02-03` stays allowed.
> - **Forgetting `resourceNames`.** Without it the group can impersonate every ServiceAccount in the namespace, including `default`.
