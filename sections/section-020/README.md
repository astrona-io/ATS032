---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Restrict ServiceAccount Credentials

Every pod receives a ServiceAccount credential unless it is switched off. This section shows how the credential reaches the container and how to turn it off, how to give each workload its own ServiceAccount with only the permissions it uses, and how to audit ServiceAccounts, bindings and tokens across a cluster.

The section has three modules and a capstone lab. Read the landing page of each module, then its parts in order, and use the playground next to the text. Each lab follows the part it practises, and the summary closes the module. A ten-question knowledge check follows each summary. The capstone lab combines the skills of all three modules.

## Learning Outcomes

- Explain how a pod gets its ServiceAccount and what is mounted.
- Disable token mounting at ServiceAccount and pod level and state which setting wins.
- Request short-lived tokens and set an audience and lifetime on a projected token.
- Create one least-privilege ServiceAccount for each workload and bind it with a Role.
- Remove grants from the `default` ServiceAccount and turn off its token mounting.
- Audit pods, bindings, group bindings and token Secrets across a cluster and fix the findings.
