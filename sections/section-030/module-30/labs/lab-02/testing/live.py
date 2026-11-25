import time

STARFLEET = 'starfleet-032-030-03-02'
OUTPOST = 'outpost-032-030-03-02'
POLICY = 'deny-nodeport'
BINDING = 'deny-nodeport-outpost'


def dry_run_service(namespace, service_type):
    body = {'apiVersion': 'v1', 'kind': 'Service', 'metadata': {'name': 'grader', 'namespace': namespace},
            'spec': {'type': service_type, 'ports': [{'port': 80}]}}
    return subprocess.run(['kubectl', 'create', '--dry-run=server', '-f', '-'], input=json.dumps(body),
                          capture_output=True, text=True, timeout=20)


def dry_run_update():
    return command(['kubectl', '-n', OUTPOST, 'patch', 'service', 'web', '--dry-run=server',
                    '-p', '{"spec": {"type": "NodePort"}}'], success=False)


def denied_by_policy(send):
    """A new policy or binding takes a few seconds to load, so ask up to five times."""
    for attempt in range(5):
        result = send()
        if result.returncode != 0 and POLICY in result.stderr:
            return result
        time.sleep(2)
    return result


web = get('service', 'web', namespace=OUTPOST)
assert web['spec'].get('type') == 'ClusterIP', f'Keep the Service web in {OUTPOST} as type ClusterIP'

if wants('create-denied'):
    result = denied_by_policy(lambda: dry_run_service(OUTPOST, 'NodePort'))
    assert result.returncode != 0 and POLICY in result.stderr, \
        f'Creating a NodePort Service in {OUTPOST} must be denied by the policy {POLICY}'
    assert dry_run_service(OUTPOST, 'ClusterIP').returncode == 0, \
        f'Creating a ClusterIP Service in {OUTPOST} must still be allowed'

if wants('update-denied'):
    result = denied_by_policy(dry_run_update)
    assert result.returncode != 0 and POLICY in result.stderr, \
        f'Changing the Service web in {OUTPOST} to NodePort must be denied by the policy {POLICY}'

if wants('binding-scoped'):
    binding = get('validatingadmissionpolicybinding', BINDING, namespace=None)
    assert binding['spec'].get('policyName') == POLICY, f'The binding {BINDING} must use the policy {POLICY}'
    assert 'Deny' in binding['spec'].get('validationActions', []), f'The binding {BINDING} must use the action Deny'
    result = denied_by_policy(lambda: dry_run_service(OUTPOST, 'NodePort'))
    assert result.returncode != 0 and BINDING in result.stderr, \
        f'A NodePort Service in {OUTPOST} must be denied through the binding {BINDING}'
    assert dry_run_service(STARFLEET, 'NodePort').returncode == 0, \
        f'A NodePort Service in {STARFLEET} must still be allowed'
