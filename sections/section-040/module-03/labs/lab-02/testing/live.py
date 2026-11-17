baseline = get('configmap', 'maintenance-baseline')['data']

if wants('runtime-restarted'):
    state = node_exec(WORKER, 'systemctl', 'show', 'containerd', '--property=ActiveState', '--property=ActiveEnterTimestampMonotonic').stdout
    values = dict(line.split('=', 1) for line in state.splitlines() if '=' in line)
    assert values.get('ActiveState') == 'active', 'containerd on the worker must be active'
    assert int(values.get('ActiveEnterTimestampMonotonic', '0')) > int(baseline['containerd-started']), 'Restart containerd on ' + WORKER
if wants('probe-pods-replaced'):
    old = set(baseline['probe-uids'].split())
    pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=probe', '-o', 'json'))['items']
    kept = [pod['metadata']['name'] for pod in pods if pod['metadata']['uid'] in old]
    assert not kept, 'Drain the worker so that the probe Pods are evicted and recreated: ' + ', '.join(kept)
    assert get('deployment', 'probe')['status'].get('availableReplicas', 0) >= 2, 'Two probe Pods must be available'
if wants('worker-in-service'):
    worker = get('node', WORKER, namespace='')
    assert any(condition['type'] == 'Ready' and condition['status'] == 'True'
               for condition in worker['status']['conditions']), WORKER + ' must be Ready'
    assert not worker['spec'].get('unschedulable'), 'Uncordon ' + WORKER
