---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Users, Groups And ServiceAccounts As Subjects

A binding gives a role to subjects, and a subject is only a name. If the name is wrong, the grant either reaches nobody or reaches someone you did not mean. To write subjects with confidence you need to know where the names come from, because Kubernetes has no User object and no Group object. This part builds one binding with all three subject kinds and tests each one.

## Where the names come from

The authentication step of the API server turns a credential into an identity: a user name, a list of groups and optional extra data. RBAC then compares those names with the subjects of the bindings. Kubernetes stores no list of users and no list of groups, so nothing checks that a name in a binding belongs to a real person.

A client certificate is one source of names. The API server takes the Common Name (CN) field of the certificate subject as the user name, and every Organization (O) field as a group. A certificate with the subject `/CN=jane/O=outpost-observers` therefore authenticates as the user `jane` in the group `outpost-observers`. Other sources are tokens from an external identity provider, where the user name and groups come from claims in the token. A ServiceAccount token gives the user name `system:serviceaccount:<namespace>:<name>` and the groups `system:serviceaccounts` and `system:serviceaccounts:<namespace>`.

You can see the certificate fields yourself. The first command creates a private key and a certificate signing request with the subject above. The second prints the subject of the request. The output shows the CN and the O field, written in the format of your OpenSSL version.

<!-- astrona:playground:renew -->

```sh
openssl req -new -newkey rsa:2048 -nodes -keyout jane.key -subj "/CN=jane/O=outpost-observers" -out jane.csr
openssl req -in jane.csr -noout -subject
```

The request is not submitted anywhere. It only shows the two fields that become the user name and the group when the cluster signs it.

## The three subject kinds

A binding lists its subjects in the field `subjects`. Each entry has a `kind` and a `name`, and the other fields depend on the kind.

- `User` uses `apiGroup: rbac.authorization.k8s.io`, which the API server fills in when you leave it out. The name is exactly the user name that authentication produces.
- `Group` uses the same `apiGroup`. The name is exactly one of the group names.
- `ServiceAccount` needs a `namespace` and must not have `apiGroup: rbac.authorization.k8s.io`. The name is the ServiceAccount name without the long prefix.

A ServiceAccount can also be written as a `User` with the name `system:serviceaccount:starfleet:probe`. Both forms match the same identity, but the `ServiceAccount` form is clearer and checked for the namespace field.

Save this as `rolebinding-observers.yaml`. It gives the built-in `view` ClusterRole in `outpost` to a user, a group and a ServiceAccount at the same time:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: observers
  namespace: outpost
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
subjects:
  - kind: User
    name: ghost
    apiGroup: rbac.authorization.k8s.io
  - kind: Group
    name: outpost-observers
    apiGroup: rbac.authorization.k8s.io
  - kind: ServiceAccount
    name: probe
    namespace: starfleet
```

Apply it:

```sh
kubectl apply -f rolebinding-observers.yaml
```

The API server accepts the binding although no user named `ghost` has ever existed. It does not look the names up. A typing mistake in a user name creates a valid binding for a person who does not exist, and the real person gets nothing, with no error.

## Test each subject

Test each subject with the identity that carries its name. The first command acts as the user `ghost`. The second acts as any user in the group `outpost-observers`. The third acts as the ServiceAccount. The fourth acts as a user with a similar name that is in no group.

```sh
kubectl auth can-i list pods -n outpost --as=ghost
kubectl auth can-i list pods -n outpost --as=anyone --as-group=outpost-observers
kubectl auth can-i list pods -n outpost --as=system:serviceaccount:starfleet:probe
kubectl auth can-i list pods -n outpost --as=ghosts
```

The first three commands print `yes`. The fourth prints `no`, because the name differs by one letter. The group test used the user name `anyone`, which shows that the group alone carries the grant. The imperative form of the same binding uses `kubectl create rolebinding observers --clusterrole=view --user=ghost --group=outpost-observers --serviceaccount=starfleet:probe -n outpost`.

```mermaid
flowchart TB
    C["Credential"] -->|"CN, O fields or token claims"| A["Authentication"]
    A -->|"user name, groups"| R["RBAC authorizer"]
    B["Binding subjects"] -->|"exact name match"| R
    R -->|"match"| G["Rules of the role"]
```

The diagram shows that authentication produces the names and the authorizer only compares them with the binding subjects, with no lookup of users.

Remove the binding when you are done, so the next part starts from the same state:

```sh
kubectl -n outpost delete rolebinding observers
```

You can now write all three subject kinds and you know that names are matched as text. The next question is which roles a binding should point at, and how the roles that Kubernetes ships are built.

## Common pitfalls

> [!WARNING]
> - **Expecting an error for a user that does not exist.** RBAC does not look names up. Test with `--as` after you write a binding.
> - **Leaving out `namespace` in a ServiceAccount subject.** The subject is invalid without it.
> - **Adding `apiGroup: rbac.authorization.k8s.io` to a ServiceAccount subject.** The API server rejects it. Only User and Group subjects use that group.
> - **Binding a person by group when the group is not in the certificate.** The `O` field of the certificate or the token claim must carry the group name.
> - **Copying a private key into a repository.** The key from the certificate request is a credential.
