# Restrict ServiceAccount Credentials

Every pod gets a credential for the Kubernetes API, even a pod that never talks to the API. The credential is a token for the pod's ServiceAccount, and Kubernetes puts it in a file inside the container. If an attacker breaks into the container, they can read that file and act as the ServiceAccount.

A ServiceAccount is the identity that a pod uses when it calls the API. Most workloads need no access at all, and the rest need only a little. In this section, you learn how the credential reaches the container and how to turn it off, how to give each workload its own ServiceAccount with only the permissions it uses, and how to audit ServiceAccounts, bindings and tokens across a cluster.

## What you will learn

The section moves from one pod to the whole cluster:

- **Restrict ServiceAccount Credentials.** How a pod gets its ServiceAccount and what is mounted, how to turn token mounting off, and short-lived tokens with an audience and a lifetime.
- **Dedicated Least-Privilege ServiceAccounts.** One ServiceAccount for each workload, bound to a Role with only the permissions it uses, and a `default` ServiceAccount with no grants and no token.
- **Audit ServiceAccount Use And Tokens.** A search across pods, bindings, group bindings and token Secrets, and how to fix what the search finds.

## How this section works

Each module has its own playground: a private `kind` cluster that runs Kubernetes v1.35. Start it from the first page of the module and keep it running while you read, because every page has commands to try.

When a page teaches a skill you can be graded on, a lab comes right after it. A lab gives you a short task in a fresh cluster and checks your result. Each module ends with a summary and a short knowledge check.

## By the end of this section

You will be able to:

- explain how a pod gets its ServiceAccount and what is mounted in the container;
- turn token mounting off on the ServiceAccount and on the pod, and say which setting wins;
- request short-lived tokens, and set an audience and a lifetime on a projected token;
- create one least-privilege ServiceAccount for each workload and bind it with a Role;
- remove grants from the `default` ServiceAccount and turn off its token mounting;
- audit pods, bindings, group bindings and token Secrets across a cluster, and fix the findings.
