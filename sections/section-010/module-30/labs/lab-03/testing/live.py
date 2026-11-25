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


STARFLEET = 'starfleet-032-010-03-03'
DOCK = 'dock-032-010-03-03'
PROBE = serviceaccount_user(STARFLEET, 'probe')
LABEL = 'fleet.example.com/aggregate-to-fleet-reader'
READ = ['get', 'list', 'watch']
POD_READS = rule_set('', ['pods'], READ)
SERVICE_READS = rule_set('', ['services'], READ)


def cluster_role(name):
    return get('clusterrole', name, None)


if wants('component-roles'):
    for name, expected in (('fleet-reader-pods', POD_READS), ('fleet-reader-services', SERVICE_READS)):
        role = cluster_role(name)
        labels = role['metadata'].get('labels') or {}
        assert labels.get(LABEL) == 'true', f'The ClusterRole {name} needs the label {LABEL}: "true"'
        same_rules(expand(role.get('rules') or []), expected, f'The ClusterRole {name}')

if wants('aggregated-role'):
    role = cluster_role('fleet-reader')
    selectors = (role.get('aggregationRule') or {}).get('clusterRoleSelectors') or []
    assert selectors, 'The ClusterRole fleet-reader needs an aggregationRule with a clusterRoleSelector'
    # The aggregation controller writes the rules; they must be the union of
    # the two labelled ClusterRoles.
    same_rules(expand(role.get('rules') or []), POD_READS | SERVICE_READS, 'The ClusterRole fleet-reader')

if wants('probe-binding'):
    binding = get('rolebinding', 'probe-fleet-reader', DOCK)
    assert binding['roleRef'].get('kind') == 'ClusterRole' and binding['roleRef'].get('name') == 'fleet-reader', \
        'The RoleBinding probe-fleet-reader must give the ClusterRole fleet-reader'
    subjects = binding.get('subjects') or []
    assert subjects and all(names_serviceaccount(subject, STARFLEET, 'probe') for subject in subjects), \
        'The RoleBinding probe-fleet-reader must name only the ServiceAccount probe of ' + STARFLEET
    same_rules(granted(PROBE, DOCK), POD_READS | SERVICE_READS, 'probe in ' + DOCK)
    same_rules(granted(PROBE, STARFLEET), set(), 'probe in ' + STARFLEET)
    cluster_wide = [label for label in bindings_naming(lambda subject: names_serviceaccount(subject, STARFLEET, 'probe'))
                    if label.startswith('ClusterRoleBinding')]
    assert not cluster_wide, 'probe must not get access through a ClusterRoleBinding: ' + ', '.join(cluster_wide)
