# RBAC helpers shared by the checks below. Access is read from the API server
# itself: `kubectl auth can-i` for single actions and a SelfSubjectRulesReview
# for the full rule set of an identity in one namespace. Rule sets are compared
# as sets of (API group, resource, resource name, verb), so the order and the
# grouping of the rules in a Role do not matter.
BASELINE_USER = 'ats-rbac-baseline'
# A ServiceAccount in a namespace that does not exist: it carries the groups
# every ServiceAccount has, so grants to those groups are not counted twice.
BASELINE_SERVICEACCOUNT = 'system:serviceaccount:ats-rbac-baseline:baseline'


def serviceaccount_user(namespace, name):
    return f'system:serviceaccount:{namespace}:{name}'


def acting_as(user, groups=()):
    return ['--as=' + user, *('--as-group=' + group for group in groups)]


def can_i(user, verb, resource, namespace=None, groups=()):
    """Ask the API server whether user (with groups) may do verb on resource."""
    scope = ['-n', namespace] if namespace else []
    result = command(['kubectl', 'auth', 'can-i', verb, resource, *scope, *acting_as(user, groups)], success=False)
    answer = result.stdout.strip()
    assert answer in ('yes', 'no'), 'kubectl auth can-i gave no answer: ' + result.stderr.strip()
    return answer == 'yes'


def expand(rules):
    """Every (group, resource, name, verb) that a list of rules allows."""
    allowed = set()
    for rule in rules or []:
        for group in rule.get('apiGroups') or []:
            for resource in rule.get('resources') or []:
                for verb in rule.get('verbs') or []:
                    for name in rule.get('resourceNames') or ['']:
                        allowed.add((group, resource, name, verb))
    return allowed


def rule_set(group, resources, verbs, names=('',)):
    return {(group, resource, name, verb) for resource in resources for verb in verbs for name in names}


def review(user, namespace, groups=()):
    """The resource rules the API server applies to user in namespace."""
    body = json.dumps({'apiVersion': 'authorization.k8s.io/v1', 'kind': 'SelfSubjectRulesReview', 'spec': {'namespace': namespace}})
    result = subprocess.run(['kubectl', 'create', '--validate=false', '-f', '-', '-o', 'json', *acting_as(user, groups)],
                            input=body, capture_output=True, text=True, timeout=20)
    assert result.returncode == 0, 'Could not read the rules of ' + user + ': ' + result.stderr.strip()
    return expand(json.loads(result.stdout)['status'].get('resourceRules'))


def granted(user, namespace, groups=()):
    """The rules user holds in namespace beyond what every identity of its kind holds."""
    baseline = BASELINE_SERVICEACCOUNT if user.startswith('system:serviceaccount:') else BASELINE_USER
    return review(user, namespace, groups) - review(baseline, namespace)


def describe(rules):
    words = []
    for group, resource, name, verb in sorted(rules):
        text = f'{verb} {resource}' + (f'.{group}' if group else '')
        words.append(text + (f' named {name}' if name else ''))
    if len(words) > 8:
        words = words[:8] + [f'and {len(words) - 8} more']
    return ', '.join(words) or 'nothing'


def same_rules(actual, expected, who):
    missing, extra = expected - actual, actual - expected
    problems = ([f'also allows: {describe(extra)}'] if extra else []) + ([f'is missing: {describe(missing)}'] if missing else [])
    assert not problems, f'{who} ' + '; '.join(problems)


def names_serviceaccount(subject, namespace, name):
    """True when a binding subject is this ServiceAccount, in either form."""
    if subject.get('kind') == 'ServiceAccount':
        return subject.get('name') == name and subject.get('namespace') == namespace
    return subject.get('kind') == 'User' and subject.get('name') == serviceaccount_user(namespace, name)


def all_bindings():
    """Every ClusterRoleBinding and every RoleBinding of every namespace."""
    cluster = json.loads(kubectl('get', 'clusterrolebindings', '-o', 'json'))['items']
    namespaced = json.loads(kubectl('get', 'rolebindings', '--all-namespaces', '-o', 'json'))['items']
    return cluster + namespaced


def binding_label(binding):
    namespace = binding['metadata'].get('namespace')
    kind = 'RoleBinding' if namespace else 'ClusterRoleBinding'
    return f'{kind} {binding["metadata"]["name"]}' + (f' in {namespace}' if namespace else '')


def bindings_naming(match):
    """Labels of the bindings that have at least one subject for which match() is true."""
    return sorted(binding_label(binding) for binding in all_bindings() if any(match(subject) for subject in binding.get('subjects') or []))


def role_rules(kind, name, namespace=None):
    return expand(get(kind, name, namespace).get('rules'))


STARFLEET = 'starfleet-032-010-03-02'
OUTPOST = 'outpost-032-010-03-02'
PROBE = serviceaccount_user(STARFLEET, 'probe')
OTHER_USER = 'ats-not-an-observer'

# Guard for every outcome: the RoleBinding observers still gives view.
binding = get('rolebinding', 'observers', OUTPOST)
assert binding['roleRef'].get('kind') == 'ClusterRole' and binding['roleRef'].get('name') == 'view', \
    'The RoleBinding observers must give the ClusterRole view'
subjects = binding.get('subjects') or []


def subjects_of(kind):
    return [subject for subject in subjects if subject.get('kind') == kind]


def is_probe(subject):
    """The ServiceAccount probe of starfleet, in the ServiceAccount form or the User form."""
    return names_serviceaccount(subject, STARFLEET, 'probe')


if wants('user-subject'):
    assert can_i('jane', 'list', 'pods', OUTPOST), 'The user jane cannot list Pods in ' + OUTPOST
    for name in ('Jane', 'ghost'):
        assert not can_i(name, 'list', 'pods', OUTPOST), f'The user {name} can still list Pods in ' + OUTPOST
    users = [subject.get('name') for subject in subjects_of('User') if not is_probe(subject)]
    assert users == ['jane'], 'The only User subject of observers must be jane; found: ' + (', '.join(users) or 'none')

if wants('group-subject'):
    assert can_i(OTHER_USER, 'list', 'pods', OUTPOST, groups=['outpost-observers']), \
        'Members of the group outpost-observers cannot list Pods in ' + OUTPOST
    assert not can_i(OTHER_USER, 'list', 'pods', OUTPOST, groups=['outpost-observer']), \
        'Members of the group outpost-observer can still list Pods in ' + OUTPOST
    groups = [subject.get('name') for subject in subjects_of('Group')]
    assert groups == ['outpost-observers'], \
        'The only Group subject of observers must be outpost-observers; found: ' + (', '.join(groups) or 'none')

if wants('serviceaccount-subject'):
    assert can_i(PROBE, 'list', 'pods', OUTPOST), 'The ServiceAccount probe of ' + STARFLEET + ' cannot list Pods in ' + OUTPOST
    assert not can_i(serviceaccount_user(OUTPOST, 'probe'), 'list', 'pods', OUTPOST), \
        'A ServiceAccount probe in ' + OUTPOST + ' can still list Pods there'
    wrong = [f"{subject.get('namespace')}/{subject.get('name')}" for subject in subjects_of('ServiceAccount')
             if not is_probe(subject)]
    assert not wrong, 'observers still names these ServiceAccounts: ' + ', '.join(wrong)
    assert any(is_probe(subject) for subject in subjects), 'observers must name the ServiceAccount probe of ' + STARFLEET
