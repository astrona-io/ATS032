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


STARFLEET = 'starfleet-032-010-02-02'
OUTPOST = 'outpost-032-010-02-02'
LAB_NAMESPACES = (STARFLEET, OUTPOST)
SCOUT = serviceaccount_user(STARFLEET, 'scout')
SHUTTLE = serviceaccount_user(STARFLEET, 'shuttle')
ANY_USER = 'ats-any-person'
OTHER_SERVICEACCOUNT = serviceaccount_user('default', 'default')
# Bindings that Kubernetes creates and keeps for itself. They reach broad
# groups on purpose and with small built-in roles, so they are not findings.
BUILT_IN = {
    'system:basic-user': ['system:authenticated'],
    'system:discovery': ['system:authenticated'],
    'system:public-info-viewer': ['system:authenticated', 'system:unauthenticated'],
    'system:service-account-issuer-discovery': ['system:serviceaccounts'],
}
EVERYONE = ('system:authenticated', 'system:unauthenticated')


def broad_bindings(names_broad_group):
    """Bindings outside the built-in set that name a matching group: every
    ClusterRoleBinding, and the RoleBindings of the lab namespaces."""
    found = []
    for binding in all_bindings():
        namespace = binding['metadata'].get('namespace')
        if namespace and namespace not in LAB_NAMESPACES:
            continue
        if not namespace and binding['metadata']['name'] in BUILT_IN \
                and binding['roleRef'].get('name') == binding['metadata']['name']:
            continue
        if any(subject.get('kind') == 'Group' and names_broad_group(subject.get('name', ''))
               for subject in binding.get('subjects') or []):
            found.append(binding_label(binding))
    return sorted(found)


def is_serviceaccount_group(name):
    return name == 'system:serviceaccounts' or \
        any(name == 'system:serviceaccounts:' + namespace for namespace in LAB_NAMESPACES)


# Guards for every outcome: the narrow grants and the built-in bindings stay.
assert can_i(SHUTTLE, 'list', 'configmaps', OUTPOST), 'Keep the ConfigMap reads of shuttle in ' + OUTPOST
assert can_i('jane', 'list', 'pods', OUTPOST, groups=['starfleet-crew']), \
    'Keep the view grant of the group starfleet-crew in ' + OUTPOST
for name, groups in BUILT_IN.items():
    binding = get('clusterrolebinding', name, None)
    present = {subject.get('name') for subject in binding.get('subjects') or [] if subject.get('kind') == 'Group'}
    assert binding['roleRef'].get('name') == name and set(groups) <= present, \
        f'Do not change the built-in ClusterRoleBinding {name}'

if wants('authenticated-grant-removed'):
    assert not can_i(ANY_USER, 'list', 'pods', OUTPOST), 'Any signed-in user can still list Pods in ' + OUTPOST
    assert not can_i(ANY_USER, 'get', 'configmaps', OUTPOST), 'Any signed-in user can still read ConfigMaps in ' + OUTPOST
    found = broad_bindings(lambda name: name in EVERYONE)
    assert not found, 'These bindings still reach system:authenticated or system:unauthenticated: ' + ', '.join(found)

if wants('serviceaccount-grants-removed'):
    assert not can_i(SCOUT, 'get', 'secrets', OUTPOST), 'scout can still read Secrets in ' + OUTPOST
    assert not can_i(SCOUT, 'create', 'deployments.apps', OUTPOST), 'scout can still create Deployments in ' + OUTPOST
    assert not can_i(SCOUT, 'list', 'pods', STARFLEET), 'scout can still list Pods in ' + STARFLEET
    assert not can_i(OTHER_SERVICEACCOUNT, 'get', 'secrets', OUTPOST), \
        'A ServiceAccount of another namespace can still read Secrets in ' + OUTPOST
    found = broad_bindings(is_serviceaccount_group)
    assert not found, 'These bindings still reach a whole group of ServiceAccounts: ' + ', '.join(found)
