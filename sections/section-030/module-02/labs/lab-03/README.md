---
exam_objectives:
- Restrict access to Kubernetes API
- Use Role Based Access Controls to minimize exposure
---
# Remove AlwaysAllow And Narrow Impersonation Rights

Author notes for lab `ats-032-lab-030-02-03`. The learner reads `question.md` and `solution.md`.

## Runtime

This is a QEMU lab, not a kind lab: the learner edits the kube-apiserver static Pod manifest with `sudo` on a real node. The VM boots from `ghcr.io/astrona-io/ubuntu-qcow2-image:24.04-cks`, built from the `cks` layer in [qcow2-base-image](https://github.com/astrona-io/qcow2-base-image/tree/main/distros/ubuntu/layers/cks). The image holds Kubernetes v1.35 and every control-plane image, so the lab needs no network.

`bootstrap/setup.sh` runs `/usr/local/sbin/astrona-kubeadm-init` (node `controlplane`, cluster `astro-ats-032-lab-030-02-03`, user `student`). It creates the namespaces `starfleet-032-030-02-03` and `outpost-032-030-02-03` with a ServiceAccount `probe` in each, and gives the group `helpdesk` `impersonate` on users, groups and ServiceAccounts through a ClusterRoleBinding. It then appends `AlwaysAllow` to `--authorization-mode`.

With `AlwaysAllow` the API server turns anonymous authentication off (log line `AnonymousAuth is not allowed with the AlwaysAllow authorizer. Resetting AnonymousAuth to false`). On the VM this was checked with the kubeadm HTTPS probes kept: anonymous `/livez` got `401` and the Pod stayed `0/1 Running` for the whole check (about two minutes). The bootstrap therefore changes the three probes to `tcpSocket` on the same host and port, and waits until `can-i list secrets --as=nobody` is `yes` and the Pod is Ready.

## Scripts and graders

astrona pipes each script into `bash` on the VM as the `astrona` account, with no other lab file next to it. Every script is therefore self-contained:

- `validate.sh` holds the shared check logic (one function per outcome and the context guard). It is the only file to edit.
- `testing/render-graders.sh` copies that logic into `validation/validate-<outcome>.sh`, `testing/verify-start.sh` and `testing/wait-solved.sh`. Run it after every change to `validate.sh`; `--check` reports stale files.
- The context guard requires `/etc/kubernetes/admin.conf` with the context `kubernetes-admin@astro-ats-032-lab-030-02-03`.

Outcomes:

| Outcome | Points | Passes when |
| --- | --- | --- |
| `authorization-mode-secure` | 1 | manifest and running Pod list `Node` and `RBAC` without `AlwaysAllow`, and a SubjectAccessReview for `nobody` listing Secrets in `kube-system` is not allowed |
| `impersonation-narrowed` | 1 | SubjectAccessReviews for group `helpdesk`: impersonating ServiceAccount `probe` in `starfleet-032-030-02-03` is allowed with an `RBAC:` reason; `probe` in `outpost-032-030-02-03`, `default` in `starfleet-032-030-02-03`, user `kubernetes-admin` and group `system:masters` are refused |

## Test

```sh
astrona validate sections/section-030/module-02/labs/lab-03 --accept-terms
astrona test sections/section-030/module-02/labs/lab-03 --accept-terms --headless
```

`testing.init` runs `testing/verify-start.sh` (every outcome fails on the start), `solution/apply.sh`, then `testing/wait-solved.sh`.
