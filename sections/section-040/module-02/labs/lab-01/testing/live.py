prefix = CLUSTER
nodes = {item['metadata']['name']: item for item in json.loads(kubectl('get', 'nodes', '-o', 'json'))['items']}
control_plane = nodes[prefix + '-control-plane']
worker = nodes[prefix + '-worker']
worker2 = nodes[prefix + '-worker2']
server_version = json.loads(kubectl('get', '--raw', '/version'))['gitVersion']
probe = get('deployment', 'probe')
client = get('pod', 'drifter', 'outpost-032-040-02-01')
expected_record = {
    'server-version': server_version,
    'kubelet-control-plane': control_plane['status']['nodeInfo']['kubeletVersion'],
    'kubelet-worker': worker['status']['nodeInfo']['kubeletVersion'],
    'kubelet-worker2': worker2['status']['nodeInfo']['kubeletVersion'],
    'container-runtime': control_plane['status']['nodeInfo']['containerRuntimeVersion'],
    'probe-image': probe['spec']['template']['spec']['containers'][0]['image'],
    'client-image': client['spec']['containers'][0]['image'],
}
if wants('version-inventory'):
    record = get('configmap', 'version-inventory').get('data', {})
    for key, value in expected_record.items():
        assert record.get(key) == value, 'Inventory value differs from the cluster: ' + key
if wants('patch-wave-labels'):
    for node, wave in ((control_plane, '1'), (worker, '2'), (worker2, '3')):
        assert node['metadata']['labels'].get('patch-wave') == wave, 'Node patch-wave label is missing or wrong: ' + node['metadata']['name']
