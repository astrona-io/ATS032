def can(verb, resource, namespace, *identity):
    # pods/log means the log subresource; as a plain argument kubectl reads it as a Pod named log
    resource, _, subresource = resource.partition('/')
    extra = ['--subresource=' + subresource] if subresource else []
    result = command(['kubectl', 'auth', 'can-i', verb, resource, *extra, '-n', namespace, *identity], success=False)
    assert result.returncode in (0, 1) and result.stdout.strip() in ('yes', 'no'), 'Authorization check failed'
    return result.returncode == 0 and result.stdout.strip() == 'yes'


OUTPOST = 'outpost-032-010-03-01'
crew = ('--as=jane', '--as-group=outpost-crew')
binding = get('rolebinding', 'outpost-crew-operator', OUTPOST)
assert binding['roleRef'] == {'apiGroup': 'rbac.authorization.k8s.io', 'kind': 'Role', 'name': 'crew-operator'}, 'Keep the Role reference of outpost-crew-operator'
assert binding['subjects'] == [{'kind': 'Group', 'name': 'outpost-crew', 'apiGroup': 'rbac.authorization.k8s.io'}], 'Keep only the group outpost-crew as subject'
role = get('role', 'crew-operator', OUTPOST)
if wants('least-privilege-rules'):
    granted = {}
    for rule in role.get('rules', []):
        assert not rule.get('resourceNames') and not rule.get('nonResourceURLs'), 'Use plain resource rules'
        for group in rule.get('apiGroups', []):
            for resource in rule.get('resources', []):
                granted.setdefault((group, resource), set()).update(rule.get('verbs', []))
    for key, verbs in granted.items():
        assert '*' not in key[0] and '*' not in key[1] and '*' not in verbs, 'Remove every wildcard from crew-operator'
    reads = {'get', 'list', 'watch'}
    writes = reads | {'create', 'update', 'patch', 'delete'}
    expected = {('', 'pods'): reads, ('', 'services'): reads, ('', 'configmaps'): reads, ('apps', 'deployments'): writes}
    assert granted == expected, 'Grant exactly the required resources and verbs'
    for verb, resource in (('list', 'pods'), ('watch', 'services'), ('get', 'configmaps'), ('create', 'deployments.apps'), ('delete', 'deployments.apps')):
        assert can(verb, resource, OUTPOST, *crew), 'outpost-crew cannot ' + verb + ' ' + resource
if wants('excess-denied'):
    for verb, resource, namespace in (('get', 'secrets', OUTPOST), ('create', 'pods', OUTPOST), ('delete', 'pods', OUTPOST), ('get', 'pods/log', OUTPOST), ('create', 'pods/exec', OUTPOST), ('create', 'rolebindings.rbac.authorization.k8s.io', OUTPOST), ('list', 'pods', NAMESPACE), ('delete', 'deployments.apps', NAMESPACE), ('get', 'nodes', OUTPOST)):
        assert not can(verb, resource, namespace, *crew), 'Excess permission granted: ' + verb + ' ' + resource + ' in ' + namespace
