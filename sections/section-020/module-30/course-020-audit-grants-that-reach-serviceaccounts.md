# Audit Grants That Reach ServiceAccounts

A token is only as dangerous as the permissions of its account. Those permissions come from bindings. A binding is an RBAC (role-based access control) object that gives the rules of a Role or ClusterRole to a list of subjects.

A binding can reach an account in two ways: it can name the account, or it can name a group that contains the account. The second way is easy to miss. On this page, you list the bindings of the playground and follow them to the accounts they reach. Then you ask the API server for the effective permissions of an account, instead of reading every Role by hand.

## Two ways a binding reaches an account

A RoleBinding or a ClusterRoleBinding has a list of subjects. Two kinds of subject matter here:

- A subject of kind `ServiceAccount` names one account and its namespace.
- A subject of kind `Group` names a group of subjects.

Kubernetes puts every ServiceAccount in two built-in groups. The group `system:serviceaccounts` holds all accounts of the cluster. The group `system:serviceaccounts:<namespace>` holds the accounts of one namespace.

A binding to one of these groups grants the Role to every account in scope. That includes accounts that have token mounting turned off, and accounts that someone creates later.

The kind of binding sets where the grant applies. A RoleBinding grants inside its own namespace, and a ClusterRoleBinding grants in all namespaces. The ClusterRole behind a binding matters too. The `view` ClusterRole reads most objects of a namespace. The `edit` ClusterRole adds write access and the right to read Secrets.

![Diagram: the ClusterRoleBinding ledger-edit names the ledger ServiceAccount directly and gives edit in all namespaces, while the RoleBinding outpost-all-view names the group system:serviceaccounts:outpost and gives view in outpost to ledger, archive and default](images/two-ways-binding-reaches.svg)

The drawing shows both paths in the playground. One binding names `ledger` directly. The other names a group, and through the group it reaches every account in `outpost`.

## List the bindings

Now find these bindings with `kubectl`. The playground has two bindings that matter: the RoleBinding in `outpost` and one ClusterRoleBinding.

The `-o wide` output prints the Role and the subjects of each binding. For a binding that names a ServiceAccount, the `SERVICEACCOUNTS` column shows `namespace/name`. For a group, the `GROUPS` column shows the group name.

<!-- astrona:playground:renew -->

```sh
kubectl -n outpost get rolebindings -o wide
kubectl get clusterrolebindings -o wide
```

The first command shows `outpost-all-view`, which gives the `view` ClusterRole to the group `system:serviceaccounts:outpost`. The second command prints many rows, and Kubernetes created most of them for its own components.

Find the row `ledger-edit`, which gives the `edit` ClusterRole to `outpost/ledger`. A ClusterRoleBinding that gives `edit` is the larger finding, because it applies in every namespace of the cluster.

In a large cluster, you need to filter the table to find the rows that matter. This command keeps only the rows that contain a ServiceAccount or a ServiceAccount group:

```sh
kubectl get clusterrolebindings -o custom-columns=NAME:.metadata.name,ROLE:.roleRef.name,KIND:.subjects[*].kind,SUBJECT:.subjects[*].name | grep -E 'ServiceAccount|system:serviceaccounts'
```

The output includes the bindings of system components and the binding `ledger-edit`. Read each row and ask two questions. Is the subject a workload of your own? Is the Role larger than the workload needs?

## Ask the API server what an account can do

Reading Roles only gives you a guess. The API server gives the real answer, because it combines every binding that applies, including group bindings and the built-in ones.

The command `kubectl auth can-i` with `--as` asks the API server the question for any subject. The commands below ask what `ledger` and `archive` may do in `outpost`.

```sh
kubectl auth can-i get secrets -n outpost --as=system:serviceaccount:outpost:ledger
kubectl auth can-i list pods -n outpost --as=system:serviceaccount:outpost:archive
kubectl auth can-i --list -n outpost --as=system:serviceaccount:outpost:archive
```

The first command prints `yes`, because `edit` can read Secrets. This is a serious finding. A token of `ledger` can read every Secret in the namespace, including the tokens of other accounts.

The second command prints `yes` too, although `archive` has token mounting turned off and no binding of its own. The reason is the group binding `outpost-all-view`. The rule list from the third command shows the `view` rules.

This result changes the rating of `archive`. Turning off the mount lowers the chance that someone steals a token from a container. But it does not reduce what the account can do. Any other way to get a token for `archive` gives the `view` rules. For example, someone with enough rights can request a token with the TokenRequest API.

## Decide what to do with each finding

Each finding has a standard answer:

- Delete a ClusterRoleBinding that gives `edit` to a workload. Give the workload a Role that lists only the verbs and objects it uses.
- Delete a binding to a ServiceAccount group. Bind the Role to the accounts that really need it.
- Start with the rights that read Secrets, because Secrets hold credentials that lead to other systems.
- Test again with `can-i` after every change.

Now you can follow a binding from its subject to the effective permissions of an account, including bindings through groups. The open question is about the credentials themselves: which tokens exist, how long they live and who accepts them.

## Common pitfalls

> [!WARNING]
> - **Searching only for the account name.** A binding to `system:serviceaccounts:<namespace>` does not contain the name of the account.
> - **Judging an account by its mount setting.** A group binding can give permissions to an account whose token is never mounted.
> - **Ignoring ClusterRoleBindings.** They apply in every namespace.
> - **Reading Roles instead of asking the API server.** `kubectl auth can-i --list --as` includes all bindings that apply.
> - **Ignoring read access to Secrets.** `edit`, and any Role that lists `secrets`, exposes other credentials.
