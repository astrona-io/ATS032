---
draft: true
exam_objectives:
- Use Role Based Access Controls to minimize exposure
---
# Use Role Based Access Controls to minimize exposure

A RoleBinding grants a reusable ClusterRole only inside the binding's namespace. Its reference to a cluster-scoped role definition does not make the grant cluster-wide. Read the binding scope and subject together.

The explanations identify the responsible components, compare intended and observed state, and work through the decisions needed to preserve the requirement. Read the worked examples as reasoning about a proposed system; no environment is started by this section.

Read the module goals, teaching and closing summary in order. YAML checks are indexed separately and appear after designated summaries. Larger domains include an intermediate checkpoint before the final review.

## Learning Outcomes

- Compare Role, ClusterRole, RoleBinding and ClusterRoleBinding.
- Evaluate namespace scope, verbs, resources and subjects.
- Explain additive grants and indirect privilege.
- Apply least privilege to a workload identity.
