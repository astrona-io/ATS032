# Curriculum Coverage

Exam: Certified Kubernetes Security Specialist (CKS). Domain: Cluster Hardening (15%).

The [official objectives](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/) were checked on 2026-10-11. Teaching structure is independently authored and does not add official requirements.

| Section | Official objective | Modules |
| --- | --- | --- |
| 010 | Use Role Based Access Controls to minimize exposure | 3 |
| 020 | Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones | 3 |
| 030 | Restrict access to Kubernetes API | 3 |
| 040 | Upgrade Kubernetes to avoid vulnerabilities | 3 |

| Section / module | Module | Teaching files |
| --- | --- | --- |
| 010 / 01 | Minimize Exposure With Role Based Access Control | Roles, Bindings And Scope; ClusterRoles, Reuse And Escalation Prevention; Additive Grants, Dangerous Verbs And Auditing Access |
| 010 / 02 | Audit And Narrow Effective Access | Ask The Authorizer Precisely; Find Every Grant That Reaches An Identity; Rewrite A Broad Grant As Least Privilege |
| 010 / 03 | Subjects, Built-In Roles And Wildcards | Users, Groups And ServiceAccounts As Subjects; Built-In And Aggregated ClusterRoles; Remove Wildcards And Narrow Rules |
| 020 / 01 | Restrict ServiceAccount Credentials | ServiceAccounts And The Default Token; Disable Automounting And Minimize Permissions; Bound Tokens, Audience And Legacy Secrets |
| 020 / 02 | Dedicated Least-Privilege ServiceAccounts | One ServiceAccount For Each Workload; Grant Only What The Workload Uses; Clean Up The Default ServiceAccount |
| 020 / 03 | Audit ServiceAccount Use And Tokens | Find Which Pods Use Which ServiceAccount; Audit Grants That Reach ServiceAccounts; Audit Tokens: Secrets, Lifetimes And Audience |
| 030 / 01 | Restrict Access To The Kubernetes API | How An API Request Is Checked; A Narrow Workload Identity; Hardening The Endpoint And The Kubelet |
| 030 / 02 | Authentication, Anonymous Access And Authorization Modes | Authentication Methods And Identities; Anonymous Access In Practice; Authorization Modes And Impersonation |
| 030 / 03 | Admission Control For API Writes | Pod Security Admission; ValidatingAdmissionPolicy With CEL; Admission Webhooks And Failure Policy |
| 040 / 01 | Upgrade Kubernetes To Avoid Vulnerabilities | Versions, Skew And Support; Cordon, Drain And Disruption Budgets; The kubeadm Upgrade Sequence; Snapshot And Verify |
| 040 / 02 | Track Vulnerabilities And Inventory Versions | Where Vulnerabilities Are Published; Inventory What The Cluster Runs; Triage A Vulnerability And Plan Patch Waves |
| 040 / 03 | Patch Nodes And Verify The Upgraded Cluster | Patch The Operating System And Container Runtime On Nodes; Verify The Cluster After An Upgrade; Rollback Limits And Restore Drills |

AUTHORING.yaml records measurable goals and adaptation sources. Every objective retains its section ID. Question banks are separate from the reading manifest and follow their declared summaries. Each module has a playground, one or more graded labs and a ten-question knowledge check.

## Hands-On Coverage

This course has 12 ungraded module playgrounds and 31 graded labs: 30 on a kind cluster with one control plane and one worker, and one on a QEMU virtual machine with a kubeadm cluster. Each lab's task and solution are registered right after the reading it practises; [LAB-COVERAGE.md](LAB-COVERAGE.md) maps every lab to its readings and outcomes. On 2026-11-17 every lab passed `astrona validate` and `astrona test --accept-terms --headless` (astrona 0.5.16, kind 0.33.0, Kubernetes v1.35.0 on Podman; the VM lab on arm64). Every outcome fails on the unsolved lab and passes after the reference solution.

| Module | Labs in teaching order |
| --- | --- |
| 010/01 | Grant Namespace Pod Read Access; Reuse A ClusterRole In One Namespace And Delegate Role Management; Revoke An Action That Several Bindings Grant |
| 010/02 | Remove Bindings To Broad Groups; Rewrite A Broad Grant As Least Privilege |
| 010/03 | Fix The Subjects Of A RoleBinding; Build An Aggregated ClusterRole; Remove Wildcards From A Group Role |
| 020/01 | Disable Unneeded ServiceAccount Tokens; Replace a Legacy Token Secret With a Projected Token |
| 020/02 | Give a Deployment Its Own ServiceAccount; Grant a ServiceAccount Least-Privilege Access; Lock Down the Default ServiceAccount |
| 020/03 | Remove Over-Broad ServiceAccount Bindings; Remove Long-Lived ServiceAccount Tokens |
| 030/01 | Give A Workload A Narrow ServiceAccount; Harden The Kubelet On A Worker Node |
| 030/02 | Remove Static Token Authentication From The API Server; Remove RBAC Grants For Anonymous Requests; Remove AlwaysAllow And Narrow Impersonation Rights |
| 030/03 | Enforce Pod Security Standards On A Namespace; Block NodePort Services With A ValidatingAdmissionPolicy; Make An Admission Webhook Fail Closed Safely |
| 040/01 | Drain A Worker Node With A PodDisruptionBudget; Upgrade A kubeadm Control Plane From v1.34 To v1.35 (QEMU VM); Save An etcd Snapshot Before An Upgrade |
| 040/02 | Record A Cluster Version Inventory With Image Digests; Triage Vulnerability Records And Label Patch Waves |
| 040/03 | Restart The Container Runtime On A Drained Worker; Verify And Repair A Cluster After Maintenance; Run An etcd Restore Drill From A Snapshot |
