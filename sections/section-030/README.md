---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Restrict access to Kubernetes API

A workload cannot use a broad role, but the API endpoint still exposes an insecure authentication path. Network access, credential verification, authorization and admission protect different parts of the control surface.

The explanations identify the responsible components, compare intended and observed state, and work through the decisions needed to preserve the requirement. Read the worked examples as reasoning about a proposed system; no environment is started by this section.

Read the module goals, teaching and closing summary in order. YAML checks are indexed separately and appear after designated summaries. Larger domains include an intermediate checkpoint before the final review.

## Learning Outcomes

- Explain the API server's identity, permission and admission checks.
- Relate API transport protection to authenticated peer identity.
- Identify risks from excessive API exposure and powerful credentials.
- Distinguish API audit evidence from application request logs.
