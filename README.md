<p align="center">
  <a href="https://astrona.io/courses/certified-kubernetes-security-specialist">
    <img src="https://astrona.io/courses/certified-kubernetes-security-specialist/domains/ATS032.svg" alt="ATS032: Cluster Hardening, part of the Certified Kubernetes Security Specialist course on Astrona" width="100%">
  </a>
</p>

# Cluster Hardening (ATS032)

Certified Kubernetes Security Specialist (CKS): Cluster Hardening, worth 15% of the official curriculum. This course belongs to ATP007.

Developed reading explains mechanisms, responsible components, examples and limits. Every section has an introduction and every module closes with a summary. Reusable YAML checks contain 5–15 questions per bank. Private playgrounds and graded labs are included.

## Course Outline

| Section / module | Module | Teaching files |
| --- | --- | --- |
| 010 / 01 | Minimize Exposure With Role Based Access Control | Roles, Bindings And Scope; ClusterRoles, Reuse And Escalation Prevention; Additive Grants, Dangerous Verbs And Auditing Access |
| 020 / 01 | Restrict ServiceAccount Credentials | ServiceAccounts And The Default Token; Disable Automounting And Minimize Permissions; Bound Tokens, Audience And Legacy Secrets |
| 030 / 01 | Restrict Access To The Kubernetes API | How An API Request Is Checked; A Narrow Workload Identity; Hardening The Endpoint And The Kubelet |
| 040 / 01 | Upgrade Kubernetes To Avoid Vulnerabilities | Versions, Skew And Support; Cordon, Drain And Disruption Budgets; The kubeadm Upgrade Sequence; Snapshot And Verify |

## Author Review

See [curriculum coverage](CURRICULUM.md), [primary sources](SOURCES.md), [question-bank documentation](ASSESSMENTS.md) and [contribution instructions](CONTRIBUTING.md).

## Hands-On Coverage

This course has 31 graded labs and 12 ungraded module playgrounds. 24 labs and 8 playgrounds run on a kind cluster with one control plane and one worker. 7 labs and 4 playgrounds run on a QEMU virtual machine with a single-node kubeadm cluster, booted from the CKS practice image `ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks`; these are the tasks that change the kubelet, the API server manifest, etcd data or the container runtime on a node. Each lab's task and solution are registered right after the reading it practises; [LAB-COVERAGE.md](LAB-COVERAGE.md) maps every lab to its readings and outcomes. The kind labs passed `astrona validate` and `astrona test --accept-terms --headless` on 2026-11-17 (astrona 0.5.16, kind 0.33.0, Kubernetes v1.35.0 on Podman). The QEMU labs passed both on 2026-11-18 on arm64 before they moved to the shared `vm/` layout that `scripts/ci/vm-lab.py` generates. GitHub Actions also starts every lab and playground on amd64 runners (`ubuntu-latest`), solves each lab with its reference solution and checks every graded outcome. Every outcome fails on the unsolved lab and passes after the reference solution.

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
