---
draft: true
exam_objectives:
- Restrict access to Kubernetes API
---
# Restrict Access To The Kubernetes API

Every request to the API server is authenticated, authorized and admitted. A weak setting in any of the three lets a stranger read cluster data or lets a valid user create a harmful object. This section follows a request through the three checks, shows how the API server identifies a caller and what an anonymous caller can reach, and then enforces rules on the content of writes. It also reviews the API server and kubelet settings that limit who can reach and use the API.

## Learning Path

1. Restrict Access To The Kubernetes API: the three checks, a narrow workload identity, and the API server and kubelet hardening settings.
2. Authentication, Anonymous Access And Authorization Modes: authentication methods, anonymous callers and the bindings that open them, authorization modes and impersonation.
3. Admission Control For API Writes: Pod Security admission, ValidatingAdmissionPolicy and admission webhooks with their failure policy.
4. Capstone: restrict API access end to end with a narrow identity, no anonymous access and admission rules.

Each module has a landing page, deep-dive parts, a summary and a ten-question knowledge check. Use the playground next to the text. Each lab follows the part it practises.

## Learning Outcomes

- Name the three checks and the status code of each failure.
- Test anonymous and token access from a pod.
- Give a workload an identity that allows one resource only.
- Name the API server and kubelet hardening settings.
- Name the authentication methods and explain why an invalid token returns 401 and not anonymous access.
- Find and remove a binding that gives anonymous callers access to cluster data.
- Name the authorization modes and say why AlwaysAllow must never be used.
- Enforce the Pod Security Standards with namespace labels.
- Write a ValidatingAdmissionPolicy and a binding that reject a forbidden object.
- Choose a webhook failure policy and explain the risk of Ignore.
