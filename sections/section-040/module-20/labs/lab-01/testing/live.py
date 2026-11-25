import re

DIGEST = re.compile(r'sha256:[0-9a-f]{64}')


def inventory():
    found = command(['kubectl', '-n', NAMESPACE, 'get', 'configmap', 'version-inventory', '-o', 'json'], success=False)
    assert found.returncode == 0, 'Create the ConfigMap version-inventory in ' + NAMESPACE
    return {key: value.strip() for key, value in (json.loads(found.stdout).get('data') or {}).items()}


def expect(record, key, value):
    assert record.get(key) == value, 'version-inventory: ' + key + ' does not match the cluster'


def kube_system_image(component):
    pods = json.loads(kubectl('-n', 'kube-system', 'get', 'pods', '-l', component, '-o', 'json'))['items']
    assert pods, 'No Pod with the label ' + component + ' in kube-system'
    return pods[0]['spec']['containers'][0]['image']


if wants('node-versions'):
    record = inventory()
    expect(record, 'server-version', json.loads(kubectl('get', '--raw', '/version'))['gitVersion'])
    control_plane = get('node', NODE, namespace='')['status']['nodeInfo']
    worker = get('node', WORKER, namespace='')['status']['nodeInfo']
    expect(record, 'kubelet-control-plane', control_plane['kubeletVersion'])
    expect(record, 'kubelet-worker', worker['kubeletVersion'])
    expect(record, 'container-runtime', worker['containerRuntimeVersion'])
if wants('component-images'):
    record = inventory()
    expect(record, 'etcd-image', kube_system_image('component=etcd'))
    expect(record, 'coredns-image', kube_system_image('k8s-app=kube-dns'))
if wants('workload-digest'):
    record = inventory()
    probe = get('deployment', 'probe')
    expect(record, 'probe-image', probe['spec']['template']['spec']['containers'][0]['image'])
    pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=probe', '-o', 'json'))['items']
    running = set()
    for pod in pods:
        for status in pod['status'].get('containerStatuses', []):
            running.update(DIGEST.findall(status.get('imageID', '')))
    assert running, 'No running probe Pod reports an image digest'
    recorded = DIGEST.findall(record.get('probe-digest', ''))
    assert len(recorded) == 1 and recorded[0] in running, 'version-inventory: probe-digest must be the sha256 digest from the imageID of a running probe Pod'
