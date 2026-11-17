def worker_address():
    node = get('node', WORKER, namespace=None)
    return next(item['address'] for item in node['status']['addresses'] if item['type'] == 'InternalIP')


def kubelet_settings():
    result = command(['kubectl', 'get', '--raw', f'/api/v1/nodes/{WORKER}/proxy/configz'], success=False)
    assert result.returncode == 0, 'The API server cannot read the configuration of the worker kubelet; is it running?'
    return json.loads(result.stdout)['kubeletconfig']


def hardened(settings):
    return (settings['authentication']['anonymous'].get('enabled') is False
            and settings['authentication'].get('webhook', {}).get('enabled') is True
            and settings['authorization'].get('mode') == 'Webhook'
            and not settings.get('readOnlyPort'))


if wants('kubelet-config-hardened'):
    settings = kubelet_settings()
    assert settings['authentication']['anonymous'].get('enabled') is False, 'The worker kubelet still accepts anonymous requests'
    assert settings['authentication'].get('webhook', {}).get('enabled') is True, 'Keep webhook token authentication on'
    assert settings['authorization'].get('mode') == 'Webhook', 'The worker kubelet must use Webhook authorization'
    assert not settings.get('readOnlyPort'), 'The read-only port of the worker kubelet must be 0'

if wants('kubelet-anon-rejected'):
    address = worker_address()
    status = node_exec(NODE, 'curl', '-sk', '-m', '5', '-o', '/dev/null', '-w', '%{http_code}',
                       f'https://{address}:10250/pods', success=False).stdout.strip()
    assert status == '401', f'An anonymous request to port 10250 must return 401, got {status or "no answer"}'
    read_only = node_exec(NODE, 'curl', '-s', '-m', '5', '-o', '/dev/null', f'http://{address}:10255/pods', success=False)
    assert read_only.returncode == 7, 'Port 10255 on the worker must refuse connections'

if wants('worker-node-ready'):
    node = get('node', WORKER, namespace=None)
    assert any(item['type'] == 'Ready' and item['status'] == 'True' for item in node['status']['conditions']), \
        'The worker node must be Ready'
    assert hardened(kubelet_settings()), 'The worker kubelet is not running with the hardened configuration yet'
    pod = get('pod', 'probe')
    assert pod['spec'].get('nodeName') == WORKER, 'The probe Pod must still run on the worker'
    logs = command(['kubectl', '-n', NAMESPACE, 'logs', 'probe'], success=False)
    assert logs.returncode == 0 and 'probe started' in logs.stdout, \
        'The API server must still read Pod logs through the worker kubelet'
