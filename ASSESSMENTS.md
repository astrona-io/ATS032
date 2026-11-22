# Reusable Question Banks

`assessments/index.yaml` lists banks in teaching order. Each bank uses schema
version 1 and the contract in `schemas/question-bank.schema.json`. This is an
authoring format for future application integration, not an existing Astrona
quiz API. No YAML question file is registered as a Markdown reading.

Banks follow their declared module summaries. Larger domains use an intermediate
checkpoint after the third section and a final domain review; smaller domains
use a final domain review. The index records covered sections and teaching order. Banks contain 5–15 original single-choice
questions, scoped to concepts taught in the course.

## Fields And Rendering

- `id`: stable bank or question identity; preserve it when editing wording.
- `scope`: section or domain checkpoint.
- `placement`: relative reading path after which the checkpoint belongs.
- `learning_objective`: the measurable outcome checked by the question.
- `source_readings`: author traceability to the teaching; not learner navigation.
- `prompt`: learner-visible question text.
- `options`: stable option IDs, answer text and per-option feedback.
- `correct_option`: the ID of the single correct option.
- `explanation`: feedback reinforcing the supported answer.

The application should send only the question ID, prompt and option IDs/text to
the learner before submission. Keep `correct_option`, `explanation` and option
explanations on the server until feedback is permitted. Match answers by option
ID, not display position, so a later renderer can shuffle choices safely.

The banks contain answer keys and are public learning material, so this is not
a secure examination bank. Do not treat scores as an official CKS result.

## Hands-On Coverage

This course has 12 ungraded module playgrounds (8 on kind, 4 on a qemu VM) and 31 graded labs (24 on kind, 7 on a qemu VM). Each lab sits right after the reading it practises, with its task before and its solution after. The kind labs passed `astrona validate` and `astrona test` on 2026-11-17 and the qemu labs on 2026-11-18 on arm64. GitHub Actions starts every lab and playground on amd64 runners, solves each lab with its reference solution and checks every graded outcome. The qemu VM boots the CKS practice image `ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks` with a single-node kubeadm cluster; the qemu labs are the tasks that change the kubelet, the API server manifest, etcd data or the container runtime on a node.

| Module | Labs in teaching order |
| --- | --- |
| 010/01 | Grant Namespace Pod Read Access; Reuse A ClusterRole In One Namespace And Delegate Role Management; Revoke An Action That Several Bindings Grant |
| 010/02 | Remove Bindings To Broad Groups; Rewrite A Broad Grant As Least Privilege |
| 010/03 | Fix The Subjects Of A RoleBinding; Build An Aggregated ClusterRole; Remove Wildcards From A Group Role |
| 020/01 | Disable Unneeded ServiceAccount Tokens; Replace a Legacy Token Secret With a Projected Token |
| 020/02 | Give a Deployment Its Own ServiceAccount; Grant a ServiceAccount Least-Privilege Access; Lock Down the Default ServiceAccount |
| 020/03 | Remove Over-Broad ServiceAccount Bindings; Remove Long-Lived ServiceAccount Tokens |
| 030/01 | Give A Workload A Narrow ServiceAccount; Harden The Kubelet On A Node |
| 030/02 | Remove Static Token Authentication From The API Server; Remove RBAC Grants For Anonymous Requests; Remove AlwaysAllow And Narrow Impersonation Rights |
| 030/03 | Enforce Pod Security Standards On A Namespace; Block NodePort Services With A ValidatingAdmissionPolicy; Make An Admission Webhook Fail Closed Safely |
| 040/01 | Drain A Worker Node With A PodDisruptionBudget; Upgrade A kubeadm Control Plane From v1.35 To v1.36; Save An etcd Snapshot Before An Upgrade |
| 040/02 | Record A Cluster Version Inventory With Image Digests; Triage Vulnerability Records And Label Patch Waves |
| 040/03 | Restart The Container Runtime On A Drained Node; Verify And Repair A Cluster After Maintenance; Restore etcd From A Snapshot |
