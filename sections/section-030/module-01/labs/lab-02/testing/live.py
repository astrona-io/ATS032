# Checks that read the kubelet on node controlplane. check.py runs this file
# inside the lab VM with NODE, node_exec(), command(), kubectl(), get() and
# wants() already defined. The node is named controlplane, as on an exam
# cluster, so the checks name it directly.
import json

NODE_NAME = 'controlplane'
NS = 'starfleet-032-030-01-02'


def kubelet_problem():
    """The first hardening setting that is still wrong, or None."""
    result = command(['kubectl', 'get', '--raw', '/api/v1/nodes/' + NODE_NAME + '/proxy/configz'], success=False)
    try:
        settings = json.loads(result.stdout).get('kubeletconfig') if result.returncode == 0 else None
    except ValueError:
        settings = None
    if not settings:
        return 'the API server cannot read the configuration of the kubelet on ' + NODE_NAME + '; is the kubelet running?'
    authentication = settings.get('authentication', {})
    if authentication.get('anonymous', {}).get('enabled') is not False:
        return 'the kubelet on ' + NODE_NAME + ' still accepts anonymous requests (authentication.anonymous.enabled)'
    if authentication.get('webhook', {}).get('enabled') is not True:
        return 'keep webhook token authentication on (authentication.webhook.enabled: true)'
    mode = settings.get('authorization', {}).get('mode')
    if mode != 'Webhook':
        return 'the kubelet on ' + NODE_NAME + " uses authorization mode '" + str(mode) + "', expected Webhook"
    port = settings.get('readOnlyPort') or 0
    if port != 0:
        return 'the read-only port of the kubelet on ' + NODE_NAME + ' is ' + str(port) + ', expected 0'
    return None


if wants('kubelet-config-hardened'):
    problem = kubelet_problem()
    assert problem is None, 'kubelet-config-hardened: ' + str(problem)

if wants('kubelet-anon-rejected'):
    address = command(['kubectl', 'get', 'node', NODE_NAME, '-o', 'jsonpath={.status.addresses[?(@.type=="InternalIP")].address}'], success=False).stdout.strip()
    assert address, 'kubelet-anon-rejected: node ' + NODE_NAME + ' has no InternalIP address'
    status = command(['curl', '-sk', '-m', '5', '-o', '/dev/null', '-w', '%{http_code}', 'https://' + address + ':10250/pods'], success=False).stdout.strip()
    assert status == '401', 'kubelet-anon-rejected: an anonymous request to https://' + address + ':10250/pods returned ' + (status or 'no answer') + ', expected 401'
    code = command(['curl', '-s', '-m', '5', '-o', '/dev/null', 'http://' + address + ':10255/pods'], success=False).returncode
    assert code == 7, 'kubelet-anon-rejected: port 10255 on ' + address + ' must refuse connections (curl exit code ' + str(code) + ', expected 7)'

if wants('node-ready'):
    node = get('node', NODE_NAME, None)
    ready = [c['status'] for c in node['status'].get('conditions', []) if c['type'] == 'Ready']
    assert ready == ['True'], 'node-ready: node ' + NODE_NAME + ' is not Ready'
    problem = kubelet_problem()
    assert problem is None, 'node-ready: the kubelet is not running with the hardened configuration yet: ' + str(problem)
    pod = command(['kubectl', '-n', NS, 'get', 'pod', 'probe', '-o', 'jsonpath={.spec.nodeName}'], success=False).stdout.strip()
    assert pod == NODE_NAME, 'node-ready: Pod probe in ' + NS + ' must still run on ' + NODE_NAME
    logs = command(['kubectl', '-n', NS, 'logs', 'probe'], success=False).stdout
    assert 'probe started' in logs, 'node-ready: the API server cannot read the logs of Pod probe through the kubelet'
