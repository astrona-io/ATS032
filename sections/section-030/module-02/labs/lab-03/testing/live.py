MANIFEST = '/etc/kubernetes/manifests/kube-apiserver.yaml'
STARFLEET = 'starfleet-032-030-02-03'
OUTPOST = 'outpost-032-030-02-03'


def review(user, groups, attributes):
    """Send a SubjectAccessReview and return (allowed, reason)."""
    body = {'apiVersion': 'authorization.k8s.io/v1', 'kind': 'SubjectAccessReview',
            'spec': {'user': user, 'groups': groups, 'resourceAttributes': attributes}}
    result = subprocess.run(['kubectl', 'create', '-o', 'json', '-f', '-'], input=json.dumps(body),
                            capture_output=True, text=True, timeout=20)
    assert result.returncode == 0, 'kubectl could not send a SubjectAccessReview'
    status = json.loads(result.stdout).get('status', {})
    return status.get('allowed', False), status.get('reason', '')


def authorization_modes(arguments):
    for argument in arguments:
        if argument.startswith('--authorization-mode='):
            return argument.split('=', 1)[1].split(',')
    return []


for namespace in (STARFLEET, OUTPOST):
    get('serviceaccount', 'probe', namespace=namespace)

if wants('authorization-mode-secure'):
    manifest = node_exec(NODE, 'cat', MANIFEST).stdout.split()
    modes = authorization_modes(manifest)
    assert 'AlwaysAllow' not in modes, f'{MANIFEST} still lists AlwaysAllow in --authorization-mode'
    assert 'Node' in modes and 'RBAC' in modes, f'{MANIFEST} must list Node and RBAC in --authorization-mode'
    pod = get('pod', 'kube-apiserver-' + NODE, namespace='kube-system')
    container = pod['spec']['containers'][0]
    running = authorization_modes(container.get('command', []) + container.get('args', []))
    assert 'AlwaysAllow' not in running and 'Node' in running and 'RBAC' in running, \
        'The running kube-apiserver must use Node and RBAC without AlwaysAllow'
    allowed, _ = review('nobody', ['system:authenticated'],
                        {'verb': 'list', 'resource': 'secrets', 'namespace': 'kube-system'})
    assert not allowed, 'A user without RBAC rules can still list Secrets in kube-system'

if wants('impersonation-narrowed'):
    caller = ('helpdesk-user', ['helpdesk', 'system:authenticated'])
    allowed, reason = review(*caller, {'verb': 'impersonate', 'resource': 'serviceaccounts',
                                       'name': 'probe', 'namespace': STARFLEET})
    assert allowed and reason.startswith('RBAC:'), \
        f'The group helpdesk must keep an RBAC rule to impersonate the ServiceAccount probe in {STARFLEET}'
    refused = [
        ('the ServiceAccount probe in ' + OUTPOST,
         {'verb': 'impersonate', 'resource': 'serviceaccounts', 'name': 'probe', 'namespace': OUTPOST}),
        ('the ServiceAccount default in ' + STARFLEET,
         {'verb': 'impersonate', 'resource': 'serviceaccounts', 'name': 'default', 'namespace': STARFLEET}),
        ('the user kubernetes-admin', {'verb': 'impersonate', 'resource': 'users', 'name': 'kubernetes-admin'}),
        ('the group system:masters', {'verb': 'impersonate', 'resource': 'groups', 'name': 'system:masters'}),
    ]
    for label, attributes in refused:
        allowed, _ = review(*caller, attributes)
        assert not allowed, f'The group helpdesk can still impersonate {label}'
