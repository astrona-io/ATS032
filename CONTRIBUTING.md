# Contributing

Read CLAUDE.md before editing. Its shared prefix is copied from ATS015, while the custom portion describes ATS032: Certified Kubernetes Security Specialist (CKS), Cluster Hardening (15%), part of ATP007.

Preserve IDs, weights and existing track registration. Develop self-contained explanations with mechanisms, examples, prerequisites and failure reasoning. Start each section with an introduction and end each module with its own Summary. Technical pages carry no `draft: true` front matter.

Each module has a playground and graded labs placed right after the reading they practise; follow the exam-ready lab rules in CLAUDE.md. Quote only command output seen in a live run. YAML questions use the local schema and separate index; preserve stable identities and supported per-option feedback.

Use primary sources in SOURCES.md and record adaptation paths in AUTHORING.yaml. Run the checks in scripts/ci (check-course-structure, lab-coverage --check, check-assessments and the test-*.py suites) when changing structure. Review Markdown and questions for semantic correctness as well as structure.
