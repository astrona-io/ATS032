OUTPOST = NAMESPACE.replace('starfleet-', 'outpost-', 1)
ANONYMOUS = {('User', 'system:anonymous'), ('Group', 'system:unauthenticated')}


def anonymous_status(path):
    """HTTP status of a request with no credentials, sent on the control plane node."""
    return node_exec(NODE, 'curl', '-sk', '-m', '5', '-o', '/dev/null', '-w', '%{http_code}',
                     'https://127.0.0.1:6443' + path, success=False).stdout.strip()


def names_anonymous(binding):
    return any((subject.get('kind'), subject.get('name')) in ANONYMOUS for subject in binding.get('subjects') or [])


def built_in(binding):
    return (binding['metadata'].get('labels') or {}).get('kubernetes.io/bootstrapping') == 'rbac-defaults'


# Guards: anonymous discovery keeps working and the built-in role is untouched.
assert anonymous_status('/version') == '200', 'An anonymous request to /version must still return 200'
public = get('clusterrolebinding', 'system:public-info-viewer', namespace=None)
assert names_anonymous(public), 'Do not change the built-in ClusterRoleBinding system:public-info-viewer'
public_rules = get('clusterrole', 'system:public-info-viewer', namespace=None).get('rules') or []
assert any('/version' in rule.get('nonResourceURLs', []) for rule in public_rules), \
    'Do not change the built-in ClusterRole system:public-info-viewer'

if wants('cluster-anonymous-removed'):
    found = [item['metadata']['name'] for item in json.loads(kubectl('get', 'clusterrolebindings', '-o', 'json'))['items']
             if names_anonymous(item) and not built_in(item)]
    assert not found, 'ClusterRoleBindings still grant anonymous requests: ' + ', '.join(sorted(found))
    status = anonymous_status(f'/api/v1/namespaces/{OUTPOST}/pods')
    assert status == '403', f'An anonymous Pod list in {OUTPOST} must return 403, got {status or "no answer"}'

if wants('namespace-anonymous-removed'):
    found = [f"{namespace}/{item['metadata']['name']}" for namespace in (NAMESPACE, OUTPOST)
             for item in json.loads(kubectl('-n', namespace, 'get', 'rolebindings', '-o', 'json'))['items']
             if names_anonymous(item)]
    assert not found, 'RoleBindings still grant anonymous requests: ' + ', '.join(sorted(found))
    status = anonymous_status(f'/api/v1/namespaces/{NAMESPACE}/secrets')
    assert status == '403', f'An anonymous Secret list in {NAMESPACE} must return 403, got {status or "no answer"}'
