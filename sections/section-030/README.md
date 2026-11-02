---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Restrict Access To The Kubernetes API

Every request to the API server is authenticated, authorized and admitted. This section follows a request through the three checks, tests anonymous and authenticated access from inside a pod, builds a narrow workload identity, and reviews the API server and kubelet settings that limit who can reach and use the API.

The section has one module. Read the landing page, then the parts in order, and use the playground next to the text. The lab follows the part it practises, and the summary closes the module. A ten-question knowledge check follows the summary.

## Learning Outcomes

- Name the three checks and the status code of each failure.
- Test anonymous and token access from a pod.
- Give a workload an identity that allows one resource only.
- Name the API server and kubelet hardening settings.
