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


STARFLEET = 'starfleet-032-010-01-02'
OUTPOST = 'outpost-032-010-01-02'
SHUTTLE = serviceaccount_user(STARFLEET, 'shuttle')
ROLE_MANAGEMENT = rule_set('rbac.authorization.k8s.io', ['roles', 'rolebindings'], ['create', 'get', 'list'])


def is_shuttle(subject):
    return names_serviceaccount(subject, STARFLEET, 'shuttle')


def check_binding(name, kind, role):
    binding = get('rolebinding', name, OUTPOST)
    assert binding['roleRef'].get('kind') == kind and binding['roleRef'].get('name') == role, \
        f'The RoleBinding {name} must reference the {kind} {role}'
    subjects = binding.get('subjects') or []
    assert subjects and all(is_shuttle(subject) for subject in subjects), \
        f'The RoleBinding {name} must name only the ServiceAccount shuttle of {STARFLEET}'


def create_role_as_shuttle(name, verb, resource):
    """Server dry run of a Role as shuttle: the API server runs its escalation check and stores nothing."""
    result = command(['kubectl', 'create', 'role', name, '--verb=' + verb, '--resource=' + resource,
                      '-n', OUTPOST, '--dry-run=server', '--as=' + SHUTTLE], success=False)
    return result.returncode == 0


if wants('view-in-outpost'):
    check_binding('shuttle-view', 'ClusterRole', 'view')
    assert can_i(SHUTTLE, 'list', 'pods', OUTPOST), 'shuttle must list Pods in ' + OUTPOST
    assert can_i(SHUTTLE, 'get', 'configmaps', OUTPOST), 'shuttle must read ConfigMaps in ' + OUTPOST
    assert not can_i(SHUTTLE, 'get', 'secrets', OUTPOST), 'shuttle must not read Secrets in ' + OUTPOST
    same_rules(granted(SHUTTLE, STARFLEET), set(), 'shuttle in ' + STARFLEET)
    cluster_wide = [label for label in bindings_naming(is_shuttle) if label.startswith('ClusterRoleBinding ')]
    assert not cluster_wide, 'shuttle must have no cluster-wide grant; found: ' + ', '.join(cluster_wide)

if wants('role-manager'):
    same_rules(role_rules('role', 'role-manager', OUTPOST), ROLE_MANAGEMENT, 'The Role role-manager')
    check_binding('shuttle-role-manager', 'Role', 'role-manager')
    view_rules = role_rules('clusterrole', 'view')
    extra = granted(SHUTTLE, OUTPOST) - view_rules - ROLE_MANAGEMENT
    assert not extra, 'shuttle in ' + OUTPOST + ' also allows: ' + describe(extra)
    for verb in ('escalate', 'bind'):
        assert not can_i(SHUTTLE, verb, 'roles.rbac.authorization.k8s.io', OUTPOST), f'shuttle must not hold {verb} on roles'
        assert not can_i(SHUTTLE, verb, 'clusterroles.rbac.authorization.k8s.io', OUTPOST), f'shuttle must not hold {verb} on clusterroles'
    assert create_role_as_shuttle('ats-grader-role-reader', 'get', 'roles.rbac.authorization.k8s.io'), \
        'shuttle must be able to create a Role in ' + OUTPOST + ' for permissions it holds'
    assert not create_role_as_shuttle('ats-grader-secret-reader', 'get', 'secrets'), \
        'shuttle must not be able to create a Role that reads Secrets'
