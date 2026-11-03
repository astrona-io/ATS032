---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Audit Grants That Reach ServiceAccounts

A token is only as dangerous as the permissions of its account. Those permissions come from bindings, and a binding can reach an account in two ways: by naming the account, or by naming a group that contains it. The second way is easy to miss. This part lists the bindings of the playground, follows them to the accounts they reach and checks the effective permissions of an account with the API server instead of reading every Role by hand.

## Two ways a binding reaches an account

A RoleBinding or ClusterRoleBinding has a list of subjects. A subject of kind `ServiceAccount` names one account and its namespace. A subject of kind `Group` names a group of subjects. Kubernetes puts every ServiceAccount in two built-in groups: `system:serviceaccounts` holds all accounts of the cluster, and `system:serviceaccounts:<namespace>` holds the accounts of one namespace.

A binding to one of these groups grants the Role to every account in scope, including accounts that have token mounting turned off and accounts created later. A RoleBinding grants inside its own namespace. A ClusterRoleBinding grants in all namespaces. The ClusterRole behind a binding also matters: `view` reads most objects of a namespace, and `edit` adds writes and reading Secrets.

## List the bindings

The playground has two bindings in `outpost`. The `-o wide` output prints the Role and the subjects of each binding. For a binding that names a ServiceAccount, the `SERVICEACCOUNTS` column shows `namespace/name`. For a group, the `GROUPS` column shows the group name.

<!-- astrona:playground:renew -->

```sh
kubectl -n outpost get rolebindings -o wide
kubectl get clusterrolebindings -o wide
```

The first command shows `outpost-all-view`, which gives the `view` ClusterRole to the group `system:serviceaccounts:outpost`. The second prints many rows, most of them created by Kubernetes for its own components. Find the row `ledger-edit`, which gives the `edit` ClusterRole to `outpost/ledger`. A ClusterRoleBinding that gives `edit` is the larger finding, because it applies in every namespace of the cluster.

To find out which rows matter in a large cluster, filter the table. This command keeps only the rows that contain a ServiceAccount or a ServiceAccount group:

```sh
kubectl get clusterrolebindings -o custom-columns=NAME:.metadata.name,ROLE:.roleRef.name,KIND:.subjects[*].kind,SUBJECT:.subjects[*].name | grep -E 'ServiceAccount|system:serviceaccounts'
```

The output includes bindings of system components and the binding `ledger-edit`. Read each row and ask whether the subject is a workload of your own and whether the Role is larger than the workload needs.

## Ask the API server what an account can do

Reading Roles gives a guess. The API server gives the answer, because it combines every binding that applies, including group bindings and the built-in ones. `kubectl auth can-i` with `--as` asks the question for any subject. The commands below ask what `ledger` and `archive` may do in `outpost`.

```sh
kubectl auth can-i get secrets -n outpost --as=system:serviceaccount:outpost:ledger
kubectl auth can-i list pods -n outpost --as=system:serviceaccount:outpost:archive
kubectl auth can-i --list -n outpost --as=system:serviceaccount:outpost:archive
```

The first command prints `yes`, because `edit` can read Secrets. This is a serious finding: a token of `ledger` can read every Secret in the namespace, including the tokens of other accounts. The second prints `yes` too, although `archive` has token mounting turned off and no binding of its own. The reason is the group binding `outpost-all-view`. The rule list in the third command shows the `view` rules.

The result changes the rating of `archive`. Turning off the mount reduces the chance that a token is stolen from a container, but it does not reduce what the account can do. Any other way to obtain a token for `archive`, such as a request with the TokenRequest API by someone with enough rights, gives the `view` rules.

## Decide what to do with each finding

Each finding has a standard answer. Delete a ClusterRoleBinding that gives `edit` to a workload, and give the workload a Role that lists only the verbs and objects it uses. Delete a binding to a ServiceAccount group, and bind the Role to the accounts that really need it. Start with the rights that read Secrets, because Secrets hold credentials that lead to other systems. Test again with `can-i` after every change.

Now you can follow a binding from its subject to the effective permissions of an account, including bindings through groups. The remaining question is about the credentials themselves: which tokens exist, how long they live and who accepts them.

## Common pitfalls

> [!WARNING]
> - **Searching only for the account name.** A binding to `system:serviceaccounts:<namespace>` does not contain the name.
> - **Judging an account by its mount setting.** A group binding can give permissions to an account whose token is never mounted.
> - **Ignoring ClusterRoleBindings.** They apply in every namespace.
> - **Reading Roles instead of asking the API server.** `kubectl auth can-i --list --as` includes all bindings that apply.
> - **Ignoring read access to Secrets.** `edit`, and any Role that lists `secrets`, exposes other credentials.
