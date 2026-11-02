# Curriculum Coverage

Exam: Certified Kubernetes Security Specialist (CKS). Domain: Cluster Hardening (15%).

The [official objectives](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/) were checked on 2026-10-11. Teaching structure is independently authored and does not add official requirements.

| Section | Official objective | Modules |
| --- | --- | --- |
| 010 | Use Role Based Access Controls to minimize exposure | 1 |
| 020 | Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones | 1 |
| 030 | Restrict access to Kubernetes API | 1 |
| 040 | Upgrade Kubernetes to avoid vulnerabilities | 1 |

| Section / module | Module | Teaching files |
| --- | --- | --- |
| 010 / 01 | Minimize Exposure With Role Based Access Control | Roles, Bindings And Scope; ClusterRoles, Reuse And Escalation Prevention; Additive Grants, Dangerous Verbs And Auditing Access |
| 020 / 01 | Restrict ServiceAccount Credentials | ServiceAccounts And The Default Token; Disable Automounting And Minimize Permissions; Bound Tokens, Audience And Legacy Secrets |
| 030 / 01 | Restrict Access To The Kubernetes API | How An API Request Is Checked; A Narrow Workload Identity; Hardening The Endpoint And The Kubelet |
| 040 / 01 | Upgrade Kubernetes To Avoid Vulnerabilities | Versions, Skew And Support; Cordon, Drain And Disruption Budgets; The kubeadm Upgrade Sequence; Snapshot And Verify |

AUTHORING.yaml records measurable goals and adaptation sources. Every objective retains its section ID. All technical readings remain draft. Question banks are separate from the reading manifest and follow their declared summaries. Each module has a playground, one lab and a ten-question knowledge check. No runtime validation is claimed.

## Hands-On Coverage

This course has 4 ungraded module playgrounds and 4 draft independent labs. Tasks and solutions are registered around each lab immediately after its teaching reading. Static configuration, shell/Python/YAML, parser, lifecycle and offline grader checks pass. Live execution remains pending because the session cannot access Podman; installed CLI configuration validation is separately blocked by its maintenance lock.

| Module | Labs in teaching order |
| --- | --- |
| 010/01 | Grant Namespace Pod Read Access |
| 020/01 | Disable Unneeded ServiceAccount Tokens |
| 030/01 | Use A Workload Identity For An API Request |
| 040/01 | Drain And Return A Worker To Service |
