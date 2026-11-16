def can(verb, resource, namespace, *identity):
    result = command(['kubectl', 'auth', 'can-i', verb, resource, '-n', namespace, *identity], success=False)
    assert result.returncode in (0, 1) and result.stdout.strip() in ('yes', 'no'), 'Authorization check failed'
    return result.returncode == 0 and result.stdout.strip() == 'yes'


def normalized(rules):
    return sorted((tuple(r.get('apiGroups', [])), tuple(r.get('resources', [])), tuple(sorted(r.get('resourceNames', []))), tuple(sorted(r.get('verbs', [])))) for r in rules)


OUTPOST = 'outpost-032-010-02-01'
scout = {'kind': 'ServiceAccount', 'name': 'scout', 'namespace': NAMESPACE}
identity = ('--as=system:serviceaccount:' + NAMESPACE + ':scout',)
assert can('list', 'configmaps', OUTPOST, '--as=system:serviceaccount:' + NAMESPACE + ':shuttle'), 'Do not remove the grant of shuttle'
assert can('list', 'pods', OUTPOST, '--as=jane', '--as-group=starfleet-crew'), 'Do not remove the grant of starfleet-crew'
if wants('scout-operator-role'):
    role = get('role', 'scout-operator', OUTPOST)
    expected = [(('',), ('pods',), (), ('get', 'list', 'watch')), (('',), ('configmaps',), ('scout-report',), ('get', 'patch', 'update'))]
    assert normalized(role.get('rules', [])) == sorted(expected), 'Grant only Pod reads and the named ConfigMap scout-report'
if wants('scout-operator-binding'):
    binding = get('rolebinding', 'scout-operator', OUTPOST)
    assert binding['roleRef'] == {'apiGroup': 'rbac.authorization.k8s.io', 'kind': 'Role', 'name': 'scout-operator'}, 'Bind the Role scout-operator'
    assert binding['subjects'] == [scout], 'Bind only the ServiceAccount scout'
    for verb, resource in (('get', 'pods'), ('list', 'pods'), ('watch', 'pods'), ('get', 'configmaps/scout-report'), ('update', 'configmaps/scout-report'), ('patch', 'configmaps/scout-report')):
        assert can(verb, resource, OUTPOST, *identity), 'scout cannot ' + verb + ' ' + resource + ' in ' + OUTPOST
if wants('cluster-grant-removed'):
    result = command(['kubectl', 'get', 'clusterrolebinding', 'scout-edit-everywhere'], success=False)
    assert result.returncode != 0, 'Delete the ClusterRoleBinding scout-edit-everywhere'
    for item in json.loads(kubectl('get', 'clusterrolebindings', '-o', 'json'))['items']:
        assert scout not in (item.get('subjects') or []), 'No ClusterRoleBinding may name scout: ' + item['metadata']['name']
    for item in json.loads(kubectl('get', 'rolebindings', '-A', '-o', 'json'))['items']:
        if scout in (item.get('subjects') or []):
            assert item['metadata']['namespace'] == OUTPOST and item['metadata']['name'] == 'scout-operator', 'No other binding may name scout'
    for verb, resource, namespace in (('get', 'secrets', OUTPOST), ('create', 'configmaps', OUTPOST), ('get', 'configmaps/other', OUTPOST), ('delete', 'pods', OUTPOST), ('list', 'pods', NAMESPACE), ('get', 'nodes', OUTPOST)):
        assert not can(verb, resource, namespace, *identity), 'Excess permission granted: ' + verb + ' ' + resource + ' in ' + namespace
