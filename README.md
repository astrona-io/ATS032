# Cluster Hardening (ATS032)

Certified Kubernetes Security Specialist (CKS): Cluster Hardening, worth 15% of the official curriculum. This course belongs to ATP007.

Developed reading explains mechanisms, responsible components, examples and limits. Every section has an introduction and every module closes with a summary. Reusable YAML checks contain 5–15 questions per bank. Technical content remains draft. Private playgrounds and draft graded labs are included.

## Course Outline

| Section / module | Module | Teaching files |
| --- | --- | --- |
| 010 / 01 | Minimize Exposure With Role Based Access Control | Roles, Bindings And Scope; ClusterRoles, Reuse And Escalation Prevention; Additive Grants, Dangerous Verbs And Auditing Access |
| 020 / 01 | Restrict ServiceAccount Credentials | ServiceAccounts And The Default Token; Disable Automounting And Minimize Permissions; Bound Tokens, Audience And Legacy Secrets |
| 030 / 01 | Restrict Access To The Kubernetes API | How An API Request Is Checked; A Narrow Workload Identity; Hardening The Endpoint And The Kubelet |
| 040 / 01 | Upgrade Kubernetes To Avoid Vulnerabilities | Versions, Skew And Support; Cordon, Drain And Disruption Budgets; The kubeadm Upgrade Sequence; Snapshot And Verify |

## Author Review

See [curriculum coverage](CURRICULUM.md), [primary sources](SOURCES.md), [question-bank documentation](ASSESSMENTS.md) and [contribution instructions](CONTRIBUTING.md). Runtime results are recorded in the PR and GitHub Actions.

## Hands-On Coverage

This course has 4 ungraded module playgrounds and 4 draft independent labs. Tasks and solutions are registered around each lab immediately after its teaching reading. Static configuration, shell/Python/YAML, parser, lifecycle and offline grader checks pass. Live execution remains pending because the session cannot access Podman; installed CLI configuration validation is separately blocked by its maintenance lock.

| Module | Labs in teaching order |
| --- | --- |
| 010/01 | Grant Namespace Pod Read Access |
| 020/01 | Disable Unneeded ServiceAccount Tokens |
| 030/01 | Use A Workload Identity For An API Request |
| 040/01 | Drain And Return A Worker To Service |

## Authoring and verification

See [AUTHORING.md](AUTHORING.md) for the lab lifecycle and review workflow, and
[LAB-COVERAGE.md](LAB-COVERAGE.md) for preparation lessons and graded outcomes.

See [lesson and lab links](LAB-COVERAGE.md) and [remaining practical gaps](COVERAGE-REVIEW.md) for the current assessment scope.
