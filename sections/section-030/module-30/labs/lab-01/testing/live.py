LABEL = 'pod-security.kubernetes.io/'


def dry_run_pod(name, security_context):
    """Send a Pod to the API server with a server-side dry run and return the result."""
    container = {'name': name, 'image': 'docker.io/library/busybox:1.37.0', 'command': ['sh', '-c', 'sleep 60']}
    if security_context:
        container['securityContext'] = security_context
    body = {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': name, 'namespace': NAMESPACE},
            'spec': {'containers': [container]}}
    return subprocess.run(['kubectl', 'create', '--dry-run=server', '-f', '-'], input=json.dumps(body),
                          capture_output=True, text=True, timeout=20)


labels = get('namespace', NAMESPACE, namespace=None)['metadata'].get('labels', {})

if wants('enforce-baseline'):
    assert labels.get(LABEL + 'enforce') == 'baseline', f'Set the label {LABEL}enforce=baseline on {NAMESPACE}'
    privileged = dry_run_pod('grader-privileged', {'privileged': True})
    assert privileged.returncode != 0 and 'violates PodSecurity' in privileged.stderr, \
        f'A privileged Pod must be rejected in {NAMESPACE}'
    plain = dry_run_pod('grader-plain', None)
    assert plain.returncode == 0, f'A Pod that meets baseline must still be admitted in {NAMESPACE}'

if wants('warn-restricted'):
    assert labels.get(LABEL + 'warn') == 'restricted', f'Set the label {LABEL}warn=restricted on {NAMESPACE}'
    plain = dry_run_pod('grader-plain', None)
    assert plain.returncode == 0 and 'would violate PodSecurity "restricted' in plain.stderr, \
        f'A Pod that breaks restricted must be admitted with a warning in {NAMESPACE}'

if wants('web-runs'):
    deployment = get('deployment', 'web')
    for container in deployment['spec']['template']['spec']['containers']:
        assert not (container.get('securityContext') or {}).get('privileged'), \
            f'The container {container["name"]} of the web Deployment still runs in privileged mode'
    status = deployment.get('status', {})
    wanted = deployment['spec'].get('replicas', 1)
    assert status.get('observedGeneration', 0) >= deployment['metadata']['generation'] \
        and status.get('updatedReplicas') == wanted and status.get('readyReplicas') == wanted \
        and status.get('replicas') == wanted, f'The web Deployment must run {wanted} ready, updated replicas'
    pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=web', '-o', 'json'))['items']
    for pod in pods:
        for container in pod['spec']['containers']:
            assert not (container.get('securityContext') or {}).get('privileged'), \
                f'The Pod {pod["metadata"]["name"]} still runs a privileged container'
