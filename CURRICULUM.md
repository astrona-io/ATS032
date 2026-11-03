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
| 040 / capstone | Run A Node Patch Window End To End | Drain under a disruption budget; move a bare Pod; record the inventory |

AUTHORING.yaml records measurable goals and adaptation sources. Every objective retains its section ID. All technical readings remain draft. Question banks are separate from the reading manifest and follow their declared summaries. Each module has a playground, one lab and a ten-question knowledge check. No runtime validation is claimed.

## Hands-On Coverage

This course has 12 ungraded module playgrounds, 12 draft module labs and 4 advanced capstone labs. Tasks and solutions are registered around each lab immediately after its teaching reading. Static configuration, shell/Python/YAML, parser, lifecycle and offline grader checks pass. Live execution remains pending because the session cannot access Podman; installed CLI configuration validation is separately blocked by its maintenance lock.

| Module | Labs in teaching order |
| --- | --- |
| 010/01 | Grant Namespace Pod Read Access |
| 020/01 | Disable Unneeded ServiceAccount Tokens |
| 030/01 | Use A Workload Identity For An API Request |
| 040/01 | Drain And Return A Worker To Service |
