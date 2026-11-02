---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
---
# Restrict ServiceAccount Credentials

Every pod receives a ServiceAccount credential unless it is switched off. This section shows how the credential reaches the container, how to turn off mounting in a ServiceAccount and in a pod, how to keep new ServiceAccounts without grants, and how to use short-lived tokens with an audience in place of long-lived Secret tokens.

The section has one module. Read the landing page, then the parts in order, and use the playground next to the text. The lab follows the part it practises, and the summary closes the module. A ten-question knowledge check follows the summary.

## Learning Outcomes

- Explain how a pod gets its ServiceAccount and what is mounted.
- Disable token mounting at ServiceAccount and pod level and state which setting wins.
- Request short-lived tokens and set an audience and lifetime on a projected token.
- Audit long-lived ServiceAccount token Secrets.
