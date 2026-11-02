---
draft: true
exam_objectives:
- Exercise caution in using service accounts e.g. disable defaults, minimize permissions
  on newly created ones
---
# Guided Practice: Disable Unneeded ServiceAccount Tokens

Use a host shell with the private kubeconfig for this module playground. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-playground-020-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-playground-020-01" || exit 1
node_name="astro-ats-032-playground-020-01-control-plane"
worker_name="astro-ats-032-playground-020-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet get pods -o wide
kubectl get nodes -o wide
```

Create ServiceAccount no-api with automountServiceAccountToken false. Run no-token-reader as that account with Pod-level automount also false. Keep the restricted security context and writable scratch volume. The Pod must be Ready and the default service-account token path must not exist. Do not grant this identity application permissions.

Save this as `serviceaccount-no-api.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: no-api
  namespace: starfleet
automountServiceAccountToken: false
---
apiVersion: v1
kind: Pod
metadata:
  name: no-token-reader
  namespace: starfleet
spec:
  restartPolicy: Never
  containers:
  - name: reader
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: scratch
      mountPath: /scratch
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  volumes:
  - name: scratch
    emptyDir: {}
  serviceAccountName: no-api
  automountServiceAccountToken: false
```

Apply the scoped correction:

```sh
kubectl apply -f serviceaccount-no-api.yaml
```

## Verify The Result

Observe the actual result. A denied request returns a nonzero status when the denial works, so run it separately from a shell sequence that stops on error. Status convergence and a successful request establish different parts of the result.

```sh
kubectl -n starfleet wait --for=condition=Ready pod/no-token-reader --timeout=180s
kubectl -n starfleet exec no-token-reader -- sh -c 'test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token && printf absent'
```

Run a workload without mounting credentials it does not need. The commands above deliberately target one environment. Keep its remaining components available so an unrelated failure cannot stand in for the required denial or correction. No example command output is presented as evidence of a completed run. A matching field alone does not establish that a process used it or that a controller reconciled it.


## Common pitfalls

> [!WARNING]
> Confirm the private context and exact node names before a change. Check the stated scope and live result. Do not change unrelated components to hide the original fault.
