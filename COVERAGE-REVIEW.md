# Teaching and assessment review

The course has teaching material for its registered lab tasks, but its readings cover a broader set of skills than its graders. Passing all environment tests proves the implemented lifecycles; it does not establish complete practical coverage of every learning objective.

`TEACHING-COVERAGE.yaml` names the preparation set for every lab. `LAB-COVERAGE.md` renders both directions: lab to preparation and reading to assessment. A preparation link means the reading teaches something used by that task, not that every operation in the reading is graded. The additional-reading list makes material without a module assessment visible. The course has no capstone labs.

## Readings without a graded lab

These four readings are listed in `additional_readings` and have no lab of their own. They prepare later tasks in the same module, and the module playground can be used to practise them, but no grader checks them directly.

- `sections/section-010/module-20/course-010-ask-the-authorizer-precisely.md`: precise `kubectl auth can-i` questions. The later labs in the module use the answers, but no outcome grades the questions themselves.
- `sections/section-030/module-10/course-010-how-an-api-request-is-checked.md`: the order of authentication, authorization and admission for an API request. It is conceptual; the later labs in the module grade a narrow ServiceAccount and the kubelet settings.
- `sections/section-040/module-10/course-010-versions-skew-and-support.md`: version skew and the support window. No lab grades a skew decision; the upgrade lab only grades the result of one upgrade from v1.35 to v1.36.
- `sections/section-040/module-20/course-010-where-vulnerabilities-are-published.md`: where Kubernetes vulnerabilities are announced. No lab reads a real advisory feed.

## Remaining practical gaps and boundaries

- The qemu labs run a single-node kubeadm cluster (node `controlplane`) with no worker node. The upgrade lab grades the control plane, the package holds and the node state; it does not upgrade a separate worker, and its grader cannot prove that the drain happened before the kubelet restart.
- The upgrade lab installs packages from an offline apt repository in the image, not from the public Kubernetes package repository.
- The vulnerability triage lab uses eight made-up records that `bootstrap/feed.py` writes for the running versions. It grades the triage rule, not the use of a real scanner or a real advisory.
- The version inventory lab grades values read from the live cluster (API server version, node status, control-plane images and the image digest of running Pods). It does not run an image scanner.
- The admission webhook lab has no running webhook server: its Service does not exist. The graders check the webhook fields, the namespace selector and dry-run Pods, so the lab shows the effect of `failurePolicy`, not the behaviour of a real webhook backend.
- The kind labs run on a kind cluster with one control plane and one worker. Behaviour that depends on node packages, systemd units or static Pod manifests is graded only in the qemu labs.

## Runtime choice

Use kind for Kubernetes API objects, RBAC, ServiceAccounts and admission whose required controllers are installed. Use QEMU when the task changes the kubelet, the API server manifest, etcd data, node packages or the container runtime on a real host. A stored setting alone is never proof that a component runs with it: the graders read the live state (for example `/configz` of the kubelet or the version the API server reports).

Keep each new lab immediately after its preparation reading.
