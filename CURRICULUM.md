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
| 010 / 01 | Authorization And Effective Permissions | RBAC Grants And Their Consequences |
| 020 / 01 | Authentication And Workload Credentials | API Identity And ServiceAccounts |
| 030 / 01 | API Server Security Boundaries | Protecting The Cluster API |
| 040 / 01 | Supported Upgrade And Node Maintenance | Cluster Upgrades And Maintenance Boundaries; Datastore Snapshots And The Limits Of Recovery |

AUTHORING.yaml records measurable goals and adaptation sources. Every objective retains its section ID. All technical readings remain draft. Question banks are separate from the reading manifest and follow their declared summaries. No labs, playgrounds or runtime validation are included.
