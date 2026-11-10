def can(verb, resource, namespace, *identity):
    result = command(['kubectl', 'auth', 'can-i', verb, resource, '-n', namespace, *identity], success=False)
    assert result.returncode in (0, 1) and result.stdout.strip() in ('yes', 'no'), 'Authorization check failed'
    return result.returncode == 0 and result.stdout.strip() == 'yes'


OUTPOST = 'outpost-032-010-01-01'
identity = '--as=system:serviceaccount:' + NAMESPACE + ':shuttle'
for verb, resource, namespace in (('create', 'pods', NAMESPACE), ('delete', 'pods', NAMESPACE), ('get', 'secrets', NAMESPACE), ('list', 'pods', OUTPOST), ('get', 'nodes', NAMESPACE)):
    assert not can(verb, resource, namespace, identity), 'Excess permission granted: ' + verb + ' ' + resource + ' in ' + namespace
if wants('pod-reader-role'):
    rules = get('role', 'pod-reader').get('rules', [])
    assert len(rules) == 1, 'Keep one narrow rule in Role pod-reader'
    rule = rules[0]
    assert rule.get('apiGroups') == [''] and rule.get('resources') == ['pods'] and set(rule.get('verbs', [])) == {'get', 'list', 'watch'}, 'Grant only get, list and watch on core Pods'
    assert not rule.get('nonResourceURLs') and not rule.get('resourceNames'), 'Allow the complete Pod collection'
if wants('shuttle-binding'):
    binding = get('rolebinding', 'shuttle-pod-reader')
    assert binding['roleRef'] == {'apiGroup': 'rbac.authorization.k8s.io', 'kind': 'Role', 'name': 'pod-reader'}, 'Bind the Role pod-reader'
    assert binding['subjects'] == [{'kind': 'ServiceAccount', 'name': 'shuttle', 'namespace': NAMESPACE}], 'Bind only the ServiceAccount shuttle'
    for verb in ('get', 'list', 'watch'):
        assert can(verb, 'pods', NAMESPACE, identity), 'shuttle cannot ' + verb + ' Pods in ' + NAMESPACE
