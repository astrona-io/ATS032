# Checks that read the authorization modes of the kube-apiserver and ask the
# API server SubjectAccessReview questions. check.py runs this file inside
# the lab VM with NODE, node_exec(), command(), kubectl(), get() and wants()
# already defined. The node is named controlplane, as on an exam cluster.
import json
import re

NODE_NAME = 'controlplane'
MANIFEST = '/etc/kubernetes/manifests/kube-apiserver.yaml'
STARFLEET = 'starfleet-032-030-02-03'
OUTPOST = 'outpost-032-030-02-03'
HELPDESK_GROUPS = ['helpdesk', 'system:authenticated']

# Guard for every outcome: the lab objects must still be there.
for namespace in (STARFLEET, OUTPOST):
    found = command(['kubectl', '-n', namespace, 'get', 'serviceaccount', 'probe'], success=False)
    assert found.returncode == 0, 'guard: ServiceAccount probe in ' + namespace + ' is not readable (is the API server running? keep the lab objects)'


def review(user, groups, attributes):
    """Send a SubjectAccessReview and return (allowed, reason)."""
    body = {'apiVersion': 'authorization.k8s.io/v1', 'kind': 'SubjectAccessReview',
            'spec': {'user': user, 'groups': groups, 'resourceAttributes': attributes}}
    result = subprocess.run(['kubectl', 'create', '-o', 'json', '-f', '-'], input=json.dumps(body),
                            capture_output=True, text=True, timeout=20)
    if result.returncode != 0:
        return False, ''
    status = json.loads(result.stdout).get('status', {})
    return status.get('allowed', False), status.get('reason', '')


def modes_of(arguments):
    for item in arguments:
        found = re.search(r'--authorization-mode=(\S+)', item)
        if found:
            return found.group(1).split(',')
    return []


def secure(modes):
    return 'AlwaysAllow' not in modes and 'Node' in modes and 'RBAC' in modes


if wants('authorization-mode-secure'):
    lines = node_exec(NODE, 'cat', MANIFEST, success=False).stdout.splitlines()
    file_modes = modes_of(lines)
    assert 'AlwaysAllow' not in file_modes, 'authorization-mode-secure: ' + MANIFEST + ' still lists AlwaysAllow in --authorization-mode'
    assert 'Node' in file_modes and 'RBAC' in file_modes, 'authorization-mode-secure: ' + MANIFEST + ' must list Node and RBAC in --authorization-mode'
    result = command(['kubectl', '-n', 'kube-system', 'get', 'pod', 'kube-apiserver-' + NODE_NAME, '-o', 'json'], success=False)
    running_modes = []
    if result.returncode == 0:
        container = json.loads(result.stdout)['spec']['containers'][0]
        running_modes = modes_of((container.get('command') or []) + (container.get('args') or []))
    assert secure(running_modes), 'authorization-mode-secure: the running kube-apiserver must use Node and RBAC without AlwaysAllow (wait for the restart)'
    allowed, _ = review('nobody', ['system:authenticated'], {'verb': 'list', 'resource': 'secrets', 'namespace': 'kube-system'})
    assert allowed is False, 'authorization-mode-secure: a user without RBAC rules can still list Secrets in kube-system'

if wants('impersonation-narrowed'):
    allowed, reason = review('helpdesk-user', HELPDESK_GROUPS, {'verb': 'impersonate', 'resource': 'serviceaccounts', 'name': 'probe', 'namespace': STARFLEET})
    assert allowed is True and reason.startswith('RBAC:'), 'impersonation-narrowed: the group helpdesk must keep an RBAC rule to impersonate the ServiceAccount probe in ' + STARFLEET
    for label, attributes in (
        ('the ServiceAccount probe in ' + OUTPOST, {'verb': 'impersonate', 'resource': 'serviceaccounts', 'name': 'probe', 'namespace': OUTPOST}),
        ('the ServiceAccount default in ' + STARFLEET, {'verb': 'impersonate', 'resource': 'serviceaccounts', 'name': 'default', 'namespace': STARFLEET}),
        ('the user kubernetes-admin', {'verb': 'impersonate', 'resource': 'users', 'name': 'kubernetes-admin'}),
        ('the group system:masters', {'verb': 'impersonate', 'resource': 'groups', 'name': 'system:masters'}),
    ):
        allowed, _ = review('helpdesk-user', HELPDESK_GROUPS, attributes)
        assert allowed is False, 'impersonation-narrowed: the group helpdesk can still impersonate ' + label
