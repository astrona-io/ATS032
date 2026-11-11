---
draft: true
---
# Restrict A Projected Token Audience

Solve this question on: `terminal`

Pod `reporter` in namespace `audience-training` has an explicit token mounted at `/identity/token`. It currently targets the Kubernetes API instead of the receiving service `telemetry.training`.

Allow 10–15 minutes for task work. Cluster startup adds time.

## Tasks

1. Recreate `reporter` with the same ServiceAccount and container, automatic token mounting disabled, and a single projected token for audience `telemetry.training`, expiration 600 seconds, mounted at `/identity/token`.
2. Use TokenReview to verify the intended audience accepts the token and a different audience rejects it. Test that the token cannot authenticate a Kubernetes API request. Do not print the credential.

## Constraints

Preserve the ServiceAccount, namespace, API configuration and running client. Do not create legacy token Secrets or change the API server's accepted audiences.

## How the answer is checked

The grader reads the current mounted token, verifies its identity and lifetime, submits live TokenReview requests and calls the Kubernetes API using an isolated credential configuration. A token decoded without signature verification is not sufficient evidence.
