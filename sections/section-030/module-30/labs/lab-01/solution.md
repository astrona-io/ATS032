---
exam_objectives:
- Restrict access to Kubernetes API
---
# Enforce Pod Security Standards On A Namespace: Solution

Connect to the lab first, so that `kubectl` talks to this lab's cluster:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-030-03-01)"
```

## Label the namespace

The Pod Security admission controller is built into the API server. It reads two labels on each namespace for this task: `pod-security.kubernetes.io/enforce` rejects Pods that break the named standard, and `pod-security.kubernetes.io/warn` only prints a warning. Add both labels in one command:

```sh
kubectl label namespace outpost-032-030-03-01 \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/warn=restricted
```

The controller checks the Pods that already run in the namespace against the new enforce level. It prints a warning for the two `web` Pods, because they are privileged, but it does not stop them. Only new Pods are rejected.

## Fix the Deployment

The `web` container does not need privileged mode, so remove the `securityContext` with `privileged: true` from the Pod template. Save this as `deployment-web.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: outpost-032-030-03-01
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - echo web started; sleep 86400
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            memory: 32Mi
```

Apply it:

```sh
kubectl apply -f deployment-web.yaml
```

The API server stores the Deployment and prints a warning that the Pod template would violate `restricted`. The warning does not block the change, because `restricted` is only in `warn` mode.

Then check the result:

```sh
kubectl -n outpost-032-030-03-01 rollout status deployment/web
kubectl -n outpost-032-030-03-01 get pods -l app=web
```

The rollout finishes, and two new `web` Pods are `Running`. The ReplicaSet controller could create them because the new Pod template meets `baseline`.

## Prove that enforcement works

A server-side dry run sends the request through admission without storing anything. Send a privileged Pod:

```sh
kubectl -n outpost-032-030-03-01 run test --image=docker.io/library/busybox:1.37.0 --privileged --dry-run=server -- sleep 60
```

The API server rejects the request. The error says that the Pod violates PodSecurity `baseline:latest` and names the privileged container.

## Common pitfalls

> [!WARNING]
> - **Expecting the label to stop running Pods.** The enforce label checks only new Pods. A privileged Deployment keeps running until its Pods are replaced.
> - **Enforcing `restricted` by mistake.** The task asks for `restricted` in `warn` mode only. Enforcing it would also block the fixed `web` Pods.
> - **Reading the Deployment status only.** If Pods are rejected, the reason is in the events of the ReplicaSet, not of the Deployment.
