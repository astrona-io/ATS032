---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Upgrade Kubernetes to avoid vulnerabilities

A node upgrade removes its ready application replicas, but the remaining nodes cannot host replacements. Version compatibility and maintenance availability are separate planning requirements.

The explanations identify the responsible components, compare intended and observed state, and work through the decisions needed to preserve the requirement. Read the worked examples as reasoning about a proposed system; no environment is started by this section.

Read the module goals, teaching and closing summary in order. YAML checks are indexed separately and appear after designated summaries. Larger domains include an intermediate checkpoint before the final review.

## Learning Outcomes

- Explain supported component-version and upgrade order.
- Distinguish cordon, drain and disruption policy.
- Evaluate datastore snapshot scope and restore prerequisites.
- Verify component and application recovery after lifecycle changes.
