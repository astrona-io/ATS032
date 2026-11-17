OUTPOST = NAMESPACE.replace('starfleet-', 'outpost-', 1)
IDENTITY = f'system:serviceaccount:{NAMESPACE}:observer'

# Sends one request from inside a Pod with the token and the certificate
# authority that Kubernetes mounts for the Pod's ServiceAccount.
IN_POD_REQUEST = '''import ssl, sys, urllib.request, urllib.error
root = '/var/run/secrets/kubernetes.io/serviceaccount'
context = ssl.create_default_context(cafile=root + '/ca.crt')
request = urllib.request.Request('https://kubernetes.default.svc' + sys.argv[1],
    headers={'Authorization': 'Bearer ' + open(root + '/token').read()})
try:
    print(urllib.request.urlopen(request, context=context, timeout=5).status)
except urllib.error.HTTPError as error:
    print(error.code)
'''


def can_i(verb, resource, namespace=NAMESPACE):
    result = command(['kubectl', 'auth', 'can-i', verb, resource, '-n', namespace, '--as', IDENTITY], success=False)
    return result.stdout.strip() == 'yes'


def names_observer(binding):
    return any(subject.get('kind') == 'ServiceAccount' and subject.get('name') == 'observer'
               and subject.get('namespace', binding['metadata'].get('namespace')) == NAMESPACE
               for subject in binding.get('subjects') or [])


if wants('observer-rbac'):
    get('serviceaccount', 'observer')
    role = get('role', 'observer-reader')
    verbs = set()
    for rule in role.get('rules') or []:
        assert set(rule.get('apiGroups', [])) == {''} and set(rule.get('resources', [])) == {'pods'}, \
            'Role observer-reader may only name core pods'
        assert not rule.get('resourceNames'), 'Role observer-reader must cover every Pod in the namespace'
        verbs |= set(rule.get('verbs', []))
    assert verbs == {'get', 'list'}, 'Role observer-reader must allow exactly get and list'
    binding = get('rolebinding', 'observer-read')
    assert binding['roleRef']['kind'] == 'Role' and binding['roleRef']['name'] == 'observer-reader', \
        'RoleBinding observer-read must refer to the Role observer-reader'
    assert names_observer(binding), 'RoleBinding observer-read must name the ServiceAccount observer'
    extra = [item['metadata']['name'] for item in json.loads(kubectl('get', 'rolebindings', '-A', '-o', 'json'))['items']
             if names_observer(item) and (item['metadata']['name'], item['metadata']['namespace']) != ('observer-read', NAMESPACE)]
    extra += [item['metadata']['name'] for item in json.loads(kubectl('get', 'clusterrolebindings', '-o', 'json'))['items']
              if names_observer(item)]
    assert not extra, 'observer has extra bindings: ' + ', '.join(sorted(extra))
    assert can_i('get', 'pods') and can_i('list', 'pods'), 'observer must get and list Pods in ' + NAMESPACE
    for verb, resource in [('watch', 'pods'), ('create', 'pods'), ('delete', 'pods'), ('get', 'secrets'), ('list', 'services')]:
        assert not can_i(verb, resource), f'observer must not {verb} {resource}'
    assert not can_i('list', 'pods', OUTPOST), 'observer must not list Pods in ' + OUTPOST

if wants('probe-uses-observer'):
    deployment = get('deployment', 'probe')
    assert deployment['spec']['template']['spec'].get('serviceAccountName') == 'observer', \
        'The probe Deployment must run as the ServiceAccount observer'
    status = deployment.get('status', {})
    replicas = deployment['spec'].get('replicas', 1)
    assert status.get('observedGeneration', 0) >= deployment['metadata']['generation'] and \
        status.get('updatedReplicas', 0) == replicas and status.get('readyReplicas', 0) == replicas, \
        'Wait until the probe rollout is complete'
    pods = [pod for pod in json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=probe', '-o', 'json'))['items']
            if not pod['metadata'].get('deletionTimestamp')]
    assert pods and all(pod['spec'].get('serviceAccountName') == 'observer' for pod in pods), \
        'Every probe Pod must run as observer'
    pod = pods[0]['metadata']['name']
    checks = [(f'/api/v1/namespaces/{NAMESPACE}/pods', '200'),
              (f'/api/v1/namespaces/{NAMESPACE}/secrets', '403'),
              (f'/api/v1/namespaces/{OUTPOST}/services', '403')]
    for path, expected in checks:
        answer = command(['kubectl', '-n', NAMESPACE, 'exec', pod, '-c', 'probe', '--',
                          'python', '-c', IN_POD_REQUEST, path], success=False).stdout.strip()
        assert answer == expected, f'A request from the probe Pod to {path} must return {expected}, got {answer or "no answer"}'
