# Checks that read the Kubernetes versions of the control plane, the node and
# the kubeadm, kubelet and kubectl packages. check.py runs this file inside
# the lab VM with NODE, node_exec(), command(), kubectl(), get() and wants()
# already defined. The node is named controlplane, as on an exam cluster.
import json

NODE_NAME = 'controlplane'
NS = 'starfleet-032-040-01-02'
TARGET_MINOR = '1.36'


def on_target_minor(version):
    """Accepts v1.36.N, 1.36.N and Debian versions such as 1.36.N-1.1."""
    return (version or '').lstrip('v').startswith(TARGET_MINOR + '.')


def tag(image):
    return (image or '').rsplit(':', 1)[-1]


if wants('control-plane-upgraded'):
    result = command(['kubectl', 'version', '-o', 'json'], success=False)
    try:
        server = json.loads(result.stdout).get('serverVersion', {}).get('gitVersion', '')
    except ValueError:
        server = ''
    assert on_target_minor(server), "control-plane-upgraded: the API server reports '" + (server or 'no answer') + "', expected v" + TARGET_MINOR + '.x'
    for component in ('kube-apiserver', 'kube-controller-manager', 'kube-scheduler'):
        listing = command(['kubectl', '-n', 'kube-system', 'get', 'pods', '-l', 'component=' + component,
                           '--field-selector', 'spec.nodeName=' + NODE_NAME, '-o', 'json'], success=False)
        items = json.loads(listing.stdout).get('items', []) if listing.returncode == 0 else []
        image = items[0]['spec']['containers'][0]['image'] if items else ''
        ready = [c['status'] for c in (items[0].get('status', {}).get('conditions', []) if items else []) if c['type'] == 'Ready']
        assert on_target_minor(tag(image)), 'control-plane-upgraded: static Pod ' + component + " runs image '" + (image or 'none') + "', expected tag v" + TARGET_MINOR + '.x'
        assert ready == ['True'], 'control-plane-upgraded: static Pod ' + component + ' on ' + NODE_NAME + ' is not Ready'
    proxy = command(['kubectl', '-n', 'kube-system', 'get', 'daemonset', 'kube-proxy', '-o', 'jsonpath={.spec.template.spec.containers[0].image}'], success=False).stdout.strip()
    assert on_target_minor(tag(proxy)), "control-plane-upgraded: DaemonSet kube-proxy uses image '" + (proxy or 'none') + "', expected tag v" + TARGET_MINOR + '.x'
    configuration = command(['kubectl', '-n', 'kube-system', 'get', 'configmap', 'kubeadm-config', '-o', 'jsonpath={.data.ClusterConfiguration}'], success=False).stdout
    recorded = [line.split(':', 1)[1].strip() for line in configuration.splitlines() if line.startswith('kubernetesVersion:')]
    config_version = recorded[0] if recorded else ''
    assert on_target_minor(config_version), "control-plane-upgraded: ConfigMap kubeadm-config records kubernetesVersion '" + (config_version or 'none') + "', expected v" + TARGET_MINOR + '.x'

if wants('packages-held'):
    held = command(['apt-mark', 'showhold'], success=False).stdout.split()
    for package in ('kubeadm', 'kubelet', 'kubectl'):
        result = command(['dpkg-query', '-W', '-f=${Version}', package], success=False)
        version = result.stdout.strip() if result.returncode == 0 else ''
        assert on_target_minor(version), 'packages-held: package ' + package + " is at '" + (version or 'not installed') + "', expected " + TARGET_MINOR + '.x'
        assert package in held, 'packages-held: package ' + package + ' (' + version + ') is not on hold (apt-mark showhold)'

if wants('node-uncordoned'):
    result = command(['kubectl', 'get', 'node', NODE_NAME, '-o', 'json'], success=False)
    assert result.returncode == 0, 'node-uncordoned: node ' + NODE_NAME + ' is not readable'
    node = json.loads(result.stdout)
    kubelet = node['status']['nodeInfo']['kubeletVersion']
    assert on_target_minor(kubelet), 'node-uncordoned: node ' + NODE_NAME + " reports kubelet '" + kubelet + "', expected v" + TARGET_MINOR + '.x (restart the kubelet after the package upgrade)'
    assert not node['spec'].get('unschedulable'), 'node-uncordoned: node ' + NODE_NAME + ' is still cordoned (SchedulingDisabled)'
    ready = [c['status'] for c in node['status'].get('conditions', []) if c['type'] == 'Ready']
    assert ready == ['True'], 'node-uncordoned: node ' + NODE_NAME + ' is not Ready'
    found = command(['kubectl', '-n', NS, 'get', 'deployment', 'probe', '-o', 'json'], success=False)
    deployment = json.loads(found.stdout) if found.returncode == 0 else {}
    desired = deployment.get('spec', {}).get('replicas')
    available = deployment.get('status', {}).get('availableReplicas', 0)
    assert desired is not None and available == desired, 'node-uncordoned: Deployment probe in ' + NS + ' has ' + str(available) + ' of ' + str(desired if desired is not None else '?') + ' replicas available'
