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


if wants('probe-serviceaccount'):
    service_account = get('serviceaccount', 'probe')
    assert service_account.get('automountServiceAccountToken') is False, \
        'The ServiceAccount probe must set automountServiceAccountToken: false'
    granted = extra_rules(account(NAMESPACE, 'probe'), NAMESPACE)
    assert not granted, 'probe must have no permissions of its own, found: ' + describe(granted)
    reaching = bindings_reaching(NAMESPACE, 'probe')
    assert not reaching, 'Remove the bindings that reach probe: ' + ', '.join(reaching)

if wants('probe-pods-without-token'):
    deployment = get('deployment', 'probe')
    assert deployment['spec']['template']['spec'].get('serviceAccountName') == 'probe', \
        'The Pod template of the Deployment probe must use the ServiceAccount probe'
    status = deployment.get('status', {})
    assert status.get('observedGeneration', 0) >= deployment['metadata']['generation'] \
        and status.get('updatedReplicas') == 2 and status.get('readyReplicas') == 2 and status.get('replicas') == 2, \
        'Wait until the rollout of the Deployment probe is complete with two ready replicas'
    pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=probe', '-o', 'json'))['items']
    pods = [pod for pod in pods if not pod['metadata'].get('deletionTimestamp')]
    assert len(pods) == 2, f'The Deployment probe must have exactly two Pods, found {len(pods)}'
    for pod in pods:
        name = pod['metadata']['name']
        assert pod['spec'].get('serviceAccountName') == 'probe', f'The Pod {name} must run as the ServiceAccount probe'
        assert not projected_token_sources(pod), f'The Pod {name} must not mount a ServiceAccount token'
        assert_no_default_token(name, NAMESPACE)
