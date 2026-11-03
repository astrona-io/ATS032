---
draft: true
exam_objectives:
- Upgrade Kubernetes to avoid vulnerabilities
---
# Where Vulnerabilities Are Published

A cluster is only as safe as the newest fix you have installed. The Kubernetes project finds out about a flaw, fixes it in a patch release and announces it. Nobody pushes that fix to your cluster for you. This part shows where the announcements appear, what a record contains and how to compare it with the version that runs.

## The sources

Kubernetes has several public sources, and each answers a different question.

- **The official CVE feed.** The Kubernetes website publishes a machine-readable list of every CVE that affects Kubernetes components. It is available as JSON and as an RSS feed, so a script or a feed reader can watch it. This is the source to automate.
- **The security announcements mailing list.** The Product Security Committee, the group that handles reports of flaws, sends a message to the list `kubernetes-security-announce` for each new CVE. The message names the affected components and the fixed versions.
- **The GitHub issue for the CVE.** Each CVE also has an issue in the Kubernetes repository with the label `official-cve-feed`. It holds the discussion and the technical detail.
- **The release notes and the changelog.** Every release has notes. They list security fixes, API removals, deprecations and a section named "Urgent Upgrade Notes" for changes that can break a cluster during an upgrade.
- **The National Vulnerability Database.** It is the general public database of CVEs for all software. It adds the severity score and links the CVE to the products.

A flaw in the container runtime, the operating system or an add-on has its own source, such as the project's security advisories or the distribution's security tracker. A cluster has many components, and each one needs a source.

## What a CVE record tells you

A record answers five questions. Which component is affected, such as the kubelet, `kube-apiserver` or `ingress-nginx`? Which versions contain the flaw? Which versions contain the fix? How severe is it? What must an attacker have to use it?

Severity is the **CVSS** (Common Vulnerability Scoring System) base score, a number from 0.0 to 10.0. A score from 9.0 is Critical, 7.0 to 8.9 is High, 4.0 to 6.9 is Medium and below that is Low. The vector string behind the score lists the conditions: whether the attacker needs network access or local access, whether the attacker needs credentials, and whether a user must do something. Read the vector, not only the number. A High flaw that needs local access to a node and a `cluster-admin` credential matters less than a Medium flaw that any anonymous client can reach over the network.

## Patch releases and the support window

A fix reaches you as a patch release. The patch version is the last number in `v1.35.2`. A patch release contains bug fixes and security fixes and no new features, so it is the lowest-risk kind of upgrade. The project issues patch releases for each supported minor version about once a month, and it issues an out-of-schedule release for a serious flaw.

Each minor version receives patches for about one year, followed by a two-month period to upgrade. After that, the version gets no more fixes, even for a published CVE. A cluster on such a version stays vulnerable until it moves to a supported minor version. So there are two questions: is there a newer patch in my minor version, and is my minor version still supported at all?

## Compare the cluster with a record

The comparison needs the exact version of the running API server. The first command prints the client and server versions. The second asks the API server for its own version document.

<!-- astrona:playground:renew -->

```sh
kubectl version
kubectl get --raw /version
```

The second command prints a JSON document. The field `gitVersion` is the server version, in the form `v1.35.0`. It also prints the Go version and the build date. Compare `gitVersion` with the "fixed in" list of a record. If the record says the fix is in `v1.35.2` and `v1.34.5`, a cluster on `v1.35.0` is affected and a patch upgrade to `v1.35.2` or newer fixes it. A cluster on `v1.33.9` is affected too, but it must first move to a version that is in the list.

The same comparison applies to each component. The kubelet version of a node is not always the API server version, because the supported skew lets nodes run older kubelets. A flaw in the kubelet is therefore matched against every node, not against the API server.

## Automate the watch

Reading announcements by hand fails the first time someone is on holiday. A better design uses the CVE feed as input to a job. The job reads the feed, filters it by component name and by the version in your inventory, and opens a ticket when a record matches. The inventory built in the next part is the second input.

You now know where records come from and how to read one. A record is useful only when you can say what your own cluster runs, which is the subject of the next part.

## Common pitfalls

> [!WARNING]
> - **Reading only the severity number.** The attack vector decides whether the flaw is reachable in your cluster.
> - **Checking the API server version alone.** A flaw in the kubelet, the runtime or an add-on is matched against that component's own version.
> - **Believing the minor version is supported because it still works.** After the support window it receives no fixes.
> - **Watching only one source.** Runtime, operating system and add-on flaws are published elsewhere.
> - **Skipping the release notes.** The urgent upgrade notes list changes that can break the upgrade itself.
