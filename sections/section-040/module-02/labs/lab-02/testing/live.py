import re


def plain_version(version):
    """v1.13.1 -> (1, 13, 1); 3.6.6-0 -> (3, 6, 6)"""
    return tuple(int(part) for part in version.lstrip('v').split('-')[0].split('.')[:3])


def kube_system_image(selector):
    pods = json.loads(kubectl('-n', 'kube-system', 'get', 'pods', '-l', selector, '-o', 'json'))['items']
    assert pods, 'No Pod with the label ' + selector + ' in kube-system'
    return pods[0]['spec']['containers'][0]['image']


if wants('affected-records'):
    running = {
        'kubelet': plain_version(get('node', WORKER, namespace='')['status']['nodeInfo']['kubeletVersion']),
        'etcd': plain_version(kube_system_image('component=etcd').rsplit(':', 1)[1]),
        'coredns': plain_version(kube_system_image('k8s-app=kube-dns').rsplit(':', 1)[1]),
        'busybox': plain_version(get('deployment', 'probe')['spec']['template']['spec']['containers'][0]['image'].rsplit(':', 1)[1]),
    }
    feed = get('configmap', 'advisory-feed')['data']['records'].splitlines()[1:]
    expected = set()
    for line in feed:
        identifier, component, introduced, fixed = line.split()[:4]
        if plain_version(introduced) <= running[component] < plain_version(fixed):
            expected.add(identifier)
    found = command(['kubectl', '-n', NAMESPACE, 'get', 'configmap', 'triage', '-o', 'json'], success=False)
    assert found.returncode == 0, 'Create the ConfigMap triage in ' + NAMESPACE
    answer = (json.loads(found.stdout).get('data') or {}).get('affected', '')
    listed = set(part for part in re.split(r'[\s,;]+', answer) if part)
    assert listed == expected, 'triage: affected must list exactly the records that apply to the running versions'
if wants('patch-waves'):
    for node, wave in ((NODE, '1'), (WORKER, '2')):
        labels = get('node', node, namespace='')['metadata'].get('labels', {})
        assert labels.get('patch-wave') == wave, 'The node ' + node + ' needs the label patch-wave=' + wave
