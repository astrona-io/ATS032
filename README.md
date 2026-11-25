<p align="center">
  <a href="https://astrona.io/courses/certified-kubernetes-security-specialist">
    <img src="https://astrona.io/courses/certified-kubernetes-security-specialist/domains/ATS032.svg" alt="ATS032: Cluster Hardening, part of the Certified Kubernetes Security Specialist course on Astrona" width="100%">
  </a>
</p>

# Certified Kubernetes Security Specialist (CKS) - Cluster Hardening (ATS032)

Learn to control who can do what in a Kubernetes cluster, and keep the cluster up to date. This course covers the Cluster Hardening domain of the Certified Kubernetes Security Specialist (CKS) exam, which is 15% of the score.

You read how each control works, try it in your own playground, and then prove it in a graded lab. Take the course on [Astrona](https://astrona.io/courses/certified-kubernetes-security-specialist).

## What you will learn

**Role based access control.** Build narrow grants, audit the access of an identity, and remove wildcards from roles.

- Minimize Exposure With Role Based Access Control
- Audit And Narrow Effective Access
- Subjects, Built-In Roles And Wildcards

**ServiceAccount credentials.** Turn off tokens that a workload does not need, give each workload its own ServiceAccount, and audit tokens across a cluster.

- Restrict ServiceAccount Credentials
- Dedicated Least-Privilege ServiceAccounts
- Audit ServiceAccount Use And Tokens

**Access to the Kubernetes API.** Follow a request through authentication, authorization and admission control, and make each check strict.

- Restrict Access To The Kubernetes API
- Authentication, Anonymous Access And Authorization Modes
- Admission Control For API Writes

**Upgrades and patches.** Upgrade a kubeadm cluster safely, track vulnerabilities, and patch and verify nodes.

- Upgrade Kubernetes To Avoid Vulnerabilities
- Track Vulnerabilities And Inventory Versions
- Patch Nodes And Verify The Upgraded Cluster

## How the course works

- **Reading pages** explain one idea at a time, with real commands and output.
- **Playgrounds** are private, ungraded environments for following along. Most run on kind (Kubernetes in Docker); the modules that change the API server, the kubelet, etcd or the container runtime use a QEMU virtual machine with a kubeadm cluster.
- **Labs** give you an exam-style task in a fresh environment and grade the result.
- **Knowledge checks** close each module with a short quiz.

You start playgrounds and labs with the `astrona` CLI, and work in a browser workspace with a terminal ready to use.

## Contributing

Found a mistake or want to improve something? See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Created by Astrona.io. Course content is licensed under [CC BY-NC-SA 4.0](LICENSE-CONTENT), and code under [AGPL v3](LICENSE). See [NOTICE](NOTICE) for details.
