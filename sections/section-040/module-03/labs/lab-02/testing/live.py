# Checks that read the containerd service on the lab VM and the probe Pods.
# check.py runs this file inside the lab VM with NODE, node_exec(), command(),
# kubectl(), get() and wants() already defined. The node is named
# controlplane, as on an exam cluster.
import json

NODE_NAME = 'controlplane'
NS = 'starfleet-032-040-03-02'


def baseline(key):
    """A value that the bootstrap recorded in the ConfigMap maintenance-baseline."""
    found = command(['kubectl', '-n', NS, 'get', 'configmap', 'maintenance-baseline', '-o', 'json'], success=False)
    if found.returncode != 0:
        return ''
    return (json.loads(found.stdout).get('data') or {}).get(key, '')


def systemd_property(name):
    return command(['systemctl', 'show', 'containerd', '--property=' + name, '--value'], success=False).stdout.strip()


if wants('runtime-restarted'):
    started = baseline('containerd-invocation')
    assert started, 'runtime-restarted: the ConfigMap maintenance-baseline in ' + NS + ' is missing; do not delete it'
    state = systemd_property('ActiveState')
    assert state == 'active', "runtime-restarted: the containerd service is '" + (state or 'unknown') + "', expected active"
    assert systemd_property('InvocationID') != started, 'runtime-restarted: containerd still runs the process that started with the lab; restart the service'

if wants('probe-pods-replaced'):
    old = baseline('probe-uids').split()
    assert old, 'probe-pods-replaced: the ConfigMap maintenance-baseline in ' + NS + ' is missing; do not delete it'
    listing = command(['kubectl', '-n', NS, 'get', 'pods', '-l', 'app=probe', '-o', 'json'], success=False)
    pods = json.loads(listing.stdout).get('items', []) if listing.returncode == 0 else []
    kept = [pod['metadata']['name'] for pod in pods if pod['metadata']['uid'] in old]
    assert not kept, 'probe-pods-replaced: drain the node so that the probe Pods are evicted and recreated; still running: ' + ', '.join(kept)
    available = command(['kubectl', '-n', NS, 'get', 'deployment', 'probe', '-o', 'jsonpath={.status.availableReplicas}'], success=False).stdout.strip()
    assert int(available or 0) >= 2, 'probe-pods-replaced: Deployment probe has ' + (available or '0') + ' available replicas, expected 2'

if wants('node-in-service'):
    result = command(['kubectl', 'get', 'node', NODE_NAME, '-o', 'json'], success=False)
    assert result.returncode == 0, 'node-in-service: node ' + NODE_NAME + ' is not readable'
    node = json.loads(result.stdout)
    ready = [c['status'] for c in node['status'].get('conditions', []) if c['type'] == 'Ready']
    assert ready == ['True'], 'node-in-service: node ' + NODE_NAME + ' is not Ready'
    assert not node['spec'].get('unschedulable'), 'node-in-service: node ' + NODE_NAME + ' is still cordoned (SchedulingDisabled)'
