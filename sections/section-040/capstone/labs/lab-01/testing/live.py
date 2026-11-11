prefix = os.environ.get('ASTRONA_KIND_CLUSTER') or 'astro-ats-032-lab-040-capstone-01'
worker = get('node', prefix + '-worker', namespace='')
assert not worker['spec'].get('unschedulable', False), 'Return the first worker to scheduling'
assert not any(taint.get('key') == 'maintenance' for taint in worker['spec'].get('taints', [])), 'Remove the leftover maintenance taint'
assert worker['metadata'].get('labels', {}).get('patch-status') == 'done', 'Label the first worker patch-status=done'
assert any(c['type'] == 'Ready' and c['status'] == 'True' for c in worker['status']['conditions']), 'Keep the first worker Ready'
budget = get('poddisruptionbudget', 'probe')
assert 'minAvailable' not in budget['spec'], 'The budget must use maxUnavailable only'
drifter = get('pod', 'drifter', 'outpost')
assert drifter['spec'].get('nodeName') == prefix + '-worker2', 'The client pod must run on the second worker'
assert drifter['status'].get('phase') == 'Running', 'The client pod must be running'
pods = json.loads(kubectl('-n', 'starfleet', 'get', 'pods', '-l', 'app=probe', '-o', 'json'))['items']
running = [pod for pod in pods if pod['status'].get('phase') == 'Running' and any(c['type'] == 'Ready' and c['status'] == 'True' for c in pod['status'].get('conditions', []))]
assert len(running) == 2, 'Both probe replicas must be running and ready'
assert len({pod['spec']['nodeName'] for pod in running}) == 2, 'The probe replicas must run on two different nodes'
baseline = get('configmap', 'maintenance-baseline')['data']['probe-pod-uid-on-worker']
on_worker = [pod for pod in running if pod['spec']['nodeName'] == prefix + '-worker']
assert on_worker and on_worker[0]['metadata']['uid'] != baseline, 'The probe pod on the first worker was not replaced by a drain'
server_version = json.loads(kubectl('get', '--raw', '/version'))['gitVersion']
probe = get('deployment', 'probe')
expected_record = {
    'server-version': server_version,
    'kubelet-worker': worker['status']['nodeInfo']['kubeletVersion'],
    'container-runtime-worker': worker['status']['nodeInfo']['containerRuntimeVersion'],
    'probe-image': probe['spec']['template']['spec']['containers'][0]['image'],
}
record = get('configmap', 'version-inventory')['data']
for key, value in expected_record.items():
    assert record.get(key) == value, 'Inventory value differs from the cluster: ' + key
