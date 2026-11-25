# Shared helpers for the ServiceAccount labs. check.py runs this file with its
# own globals (json, subprocess, command, kubectl, get, wants, NAMESPACE).
import base64

DEFAULT_TOKEN_DIRECTORY = '/var/run/secrets/kubernetes.io/serviceaccount'
# A ServiceAccount in a namespace that does not exist: it receives only the
# rules that every ServiceAccount of the cluster receives.
BASELINE_SUBJECT = 'system:serviceaccount:astrona-grader-baseline:nobody'


def account(namespace, name):
    return f'system:serviceaccount:{namespace}:{name}'


def create_from(document, *extra):
    """Send one API object to the API server and return the answer."""
    result = subprocess.run(['kubectl', 'create', '--validate=false', '-f', '-', '-o', 'json', *extra],
                            input=json.dumps(document), capture_output=True, text=True, timeout=20)
    assert result.returncode == 0, 'The API server did not answer a review request'
    return json.loads(result.stdout).get('status') or {}


def rules(subject, namespace):
    """Every permission of a subject in a namespace, as the API server computes it."""
    status = create_from({'apiVersion': 'authorization.k8s.io/v1', 'kind': 'SelfSubjectRulesReview',
                          'spec': {'namespace': namespace}}, '--as=' + subject)
    found = set()
    for rule in status.get('resourceRules', []):
        for group in rule.get('apiGroups') or ['']:
            for resource in rule.get('resources') or []:
                for verb in rule.get('verbs') or []:
                    for resource_name in rule.get('resourceNames') or ['']:
                        found.add((group, resource, verb, resource_name))
    for rule in status.get('nonResourceRules', []):
        for url in rule.get('nonResourceURLs') or []:
            for verb in rule.get('verbs') or []:
                found.add(('non-resource', url, verb, ''))
    return found


def extra_rules(subject, namespace):
    """Permissions a subject has beyond what every ServiceAccount has."""
    return rules(subject, namespace) - rules(BASELINE_SUBJECT, namespace)


def describe(found):
    words = sorted(f'{verb} {group + "/" if group else ""}{resource}' + (f'/{name}' if name else '')
                   for group, resource, verb, name in found)
    return ', '.join(words[:8]) + (f' and {len(words) - 8} more' if len(words) > 8 else '')


def bindings_reaching(namespace, name):
    """RoleBindings and ClusterRoleBindings that name the ServiceAccount or its namespace group."""
    items = json.loads(kubectl('get', 'rolebindings', '-A', '-o', 'json'))['items']
    items += json.loads(kubectl('get', 'clusterrolebindings', '-o', 'json'))['items']
    found = []
    for binding in items:
        for subject in binding.get('subjects') or []:
            kind, subject_name = subject.get('kind'), subject.get('name')
            if (kind == 'ServiceAccount' and subject_name == name and subject.get('namespace') == namespace) \
                    or (kind == 'User' and subject_name == account(namespace, name)) \
                    or (kind == 'Group' and subject_name == 'system:serviceaccounts:' + namespace):
                found.append(binding['metadata']['name'])
    return found


def ready_pod(name, namespace=NAMESPACE):
    pod = get('pod', name, namespace)
    assert not pod['metadata'].get('deletionTimestamp'), f'Pod {name} is being deleted; wait for the new Pod'
    status = pod.get('status', {})
    assert status.get('phase') == 'Running' and any(
        condition['type'] == 'Ready' and condition['status'] == 'True' for condition in status.get('conditions', [])), \
        f'Pod {name} in {namespace} must be running and ready'
    return pod


def run_in(pod, namespace, *args, container=None):
    scope = ['-c', container] if container else []
    return command(['kubectl', '-n', namespace, 'exec', pod, *scope, '--', *args], success=False)


def assert_no_default_token(pod, namespace, container=None):
    result = run_in(pod, namespace, 'test', '!', '-e', DEFAULT_TOKEN_DIRECTORY, container=container)
    assert result.returncode == 0, f'Pod {pod} in {namespace} still has {DEFAULT_TOKEN_DIRECTORY}'


def projected_token_sources(pod):
    return [source['serviceAccountToken'] for volume in pod['spec'].get('volumes') or []
            for source in (volume.get('projected') or {}).get('sources') or [] if 'serviceAccountToken' in source]


def read_token(pod, namespace, path):
    result = run_in(pod, namespace, 'cat', path)
    assert result.returncode == 0 and result.stdout.strip(), f'Pod {pod} has no token file {path}'
    return result.stdout.strip()


def claims(token):
    """The claims of a JSON Web Token. The token itself is never printed."""
    try:
        payload = token.split('.')[1]
        return json.loads(base64.urlsafe_b64decode(payload + '=' * (-len(payload) % 4)))
    except (IndexError, ValueError):
        raise AssertionError('The token file does not hold a JSON Web Token')


def review_token(token, audiences=None):
    spec = {'token': token}
    if audiences:
        spec['audiences'] = audiences
    return create_from({'apiVersion': 'authentication.k8s.io/v1', 'kind': 'TokenReview', 'spec': spec})


OUTPOST = 'outpost-032-020-02-03'
NAMESPACES = (NAMESPACE, OUTPOST)

if wants('default-grants-removed'):
    get('role', 'pod-access')
    for namespace in NAMESPACES:
        for scope in NAMESPACES:
            granted = extra_rules(account(namespace, 'default'), scope)
            assert not granted, f'The default ServiceAccount of {namespace} still has permissions in {scope}: ' \
                + describe(granted)
        reaching = [name for name in bindings_reaching(namespace, 'default')]
        assert not reaching, f'Remove the bindings that reach the default ServiceAccount of {namespace}: ' \
            + ', '.join(reaching)

if wants('default-automount-off'):
    for namespace in NAMESPACES:
        service_account = get('serviceaccount', 'default', namespace)
        assert service_account.get('automountServiceAccountToken') is False, \
            f'The default ServiceAccount of {namespace} must set automountServiceAccountToken: false'

if wants('pods-without-token'):
    for pod_name, namespace in (('shuttle', NAMESPACE), ('drifter', OUTPOST)):
        pod = ready_pod(pod_name, namespace)
        assert not projected_token_sources(pod), f'The Pod {pod_name} in {namespace} must not mount a ServiceAccount token'
        assert_no_default_token(pod_name, namespace)
