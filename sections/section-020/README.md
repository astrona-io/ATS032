---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions
  on newly created ones
---
# Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones

An example `probe` application can run without reading Kubernetes resources, while a controller needs a workload identity to call the API. Giving both the same mounted credentials exposes authority where it may not be needed.

The explanations identify the responsible components, compare intended and observed state, and work through the decisions needed to preserve the requirement. Read the worked examples as reasoning about a proposed system; no environment is started by this section.

Read the module goals, teaching and closing summary in order. YAML checks are indexed separately and appear after designated summaries. Larger domains include an intermediate checkpoint before the final review.

## Learning Outcomes

- Distinguish established identity from granted API permission.
- Explain ServiceAccount token audience and lifetime.
- Identify unnecessary credential mounting and disclosure paths.
- Relate authentication failure to the actual credential mechanism.
