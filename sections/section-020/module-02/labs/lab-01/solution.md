# Give a Deployment Its Own ServiceAccount: Solution

A Deployment does not run containers itself. It writes a Pod template, and the ReplicaSet controller creates Pods from that template. So the ServiceAccount must be set in the template, and the change reaches the containers only when the Deployment controller has rolled out new Pods.

## Step 1: Look at the starting Pods

First connect to the lab cluster:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-032-lab-020-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-032-lab-020-02-01" || exit 1
```

List the Pods of the Deployment with the ServiceAccount each one uses:

```sh
kubectl -n starfleet-032-020-02-01 get pods -l app=probe -o custom-columns=NAME:.metadata.name,SERVICEACCOUNT:.spec.serviceAccountName
```

```text
NAME                     SERVICEACCOUNT
probe-6548d5858b-hbw7v   default
probe-6548d5858b-rkldp   default
```

Both Pods run as `default`, so the kubelet mounts a token into each of them. Your Pod names differ.

## Step 2: Create the ServiceAccount

Save this as `serviceaccount-probe.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: probe
  namespace: starfleet-032-020-02-01
automountServiceAccountToken: false
```

Apply it:

```sh
kubectl apply -f serviceaccount-probe.yaml
```

```text
serviceaccount/probe created
```

Do not create a Role or a binding for `probe`. The web server does not call the API server, so the ServiceAccount needs no permission.

## Step 3: Move the Deployment to the new ServiceAccount

The command `kubectl set serviceaccount` changes `spec.template.spec.serviceAccountName` in the Deployment. Editing the same field with `kubectl edit` gives the same result. The change to the template starts a rollout:

```sh
kubectl -n starfleet-032-020-02-01 set serviceaccount deployment/probe probe
kubectl -n starfleet-032-020-02-01 rollout status deployment/probe --timeout=120s
```

```text
deployment.apps/probe serviceaccount updated
Waiting for deployment "probe" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "probe" rollout to finish: 1 old replicas are pending termination...
deployment "probe" successfully rolled out
```

The output is shortened: `kubectl` repeats some of the waiting lines.

## Step 4: Check every Pod

List the Pods again and look inside each one:

```sh
kubectl -n starfleet-032-020-02-01 get pods -l app=probe -o custom-columns=NAME:.metadata.name,SERVICEACCOUNT:.spec.serviceAccountName
for pod in $(kubectl -n starfleet-032-020-02-01 get pods -l app=probe -o name); do
  kubectl -n starfleet-032-020-02-01 exec "$pod" -- ls /var/run/secrets/kubernetes.io/serviceaccount
done
```

```text
NAME                     SERVICEACCOUNT
probe-6548d5858b-hbw7v   default
probe-6548d5858b-rkldp   default
probe-68f4d4cfcb-rd55d   probe
probe-68f4d4cfcb-snznn   probe
ca.crt
namespace
token
ca.crt
namespace
token
ls: /var/run/secrets/kubernetes.io/serviceaccount: No such file or directory
command terminated with exit code 1
ls: /var/run/secrets/kubernetes.io/serviceaccount: No such file or directory
command terminated with exit code 1
```

The two old Pods still exist for a short time. They are terminating: the web server runs as process 1 in its container and does not stop on the TERM signal, so the kubelet waits the default grace period of 30 seconds before it kills it. The two new Pods run as `probe` and have no token directory. Run the commands again after half a minute, and only the two new Pods remain.
