import time

STARFLEET = 'starfleet-032-030-03-03'
WEBHOOK = 'image-review.astrona.io'


def selector_matches(selector, labels):
    """Evaluate a Kubernetes label selector against a set of labels."""
    for key, value in (selector.get('matchLabels') or {}).items():
        if labels.get(key) != value:
            return False
    for expression in selector.get('matchExpressions') or []:
        key, operator, values = expression['key'], expression['operator'], expression.get('values') or []
        if operator == 'In' and labels.get(key) not in values:
            return False
        if operator == 'NotIn' and key in labels and labels[key] in values:
            return False
        if operator == 'Exists' and key not in labels:
            return False
        if operator == 'DoesNotExist' and key in labels:
            return False
    return True


def namespace_labels(name):
    return get('namespace', name, namespace=None)['metadata'].get('labels', {})


def dry_run_pod(namespace):
    body = {'apiVersion': 'v1', 'kind': 'Pod',
            'metadata': {'name': 'grader', 'namespace': namespace, 'labels': {'review': 'image'}},
            'spec': {'containers': [{'name': 'grader', 'image': 'docker.io/library/busybox:1.37.0'}]}}
    return subprocess.run(['kubectl', 'create', '--dry-run=server', '-f', '-'], input=json.dumps(body),
                          capture_output=True, text=True, timeout=20)


configuration = get('validatingwebhookconfiguration', 'image-review', namespace=None)
webhooks = [item for item in configuration.get('webhooks', []) if item.get('name') == WEBHOOK]
assert webhooks, f'Keep the webhook {WEBHOOK} in the ValidatingWebhookConfiguration image-review'
webhook = webhooks[0]
assert any('pods' in rule.get('resources', []) and 'CREATE' in rule.get('operations', [])
           for rule in webhook.get('rules', [])), f'The webhook {WEBHOOK} must still check Pod CREATE requests'

if wants('fails-closed'):
    assert webhook.get('failurePolicy') == 'Fail', f'Set failurePolicy of {WEBHOOK} to Fail'
    for attempt in range(5):
        result = dry_run_pod(STARFLEET)
        if result.returncode != 0 and 'failed calling webhook' in result.stderr:
            break
        time.sleep(2)
    assert result.returncode != 0 and 'failed calling webhook' in result.stderr, \
        f'A labelled Pod in {STARFLEET} must be rejected when the webhook cannot be called'

if wants('timeout-bounded'):
    timeout = webhook.get('timeoutSeconds')
    assert isinstance(timeout, int) and 1 <= timeout <= 10, \
        f'Set timeoutSeconds of {WEBHOOK} to 10 or less, now {timeout}'

if wants('skips-system'):
    selector = webhook.get('namespaceSelector') or {}
    assert not selector_matches(selector, namespace_labels('kube-system')), \
        f'The namespaceSelector of {WEBHOOK} must not select kube-system'
    assert selector_matches(selector, namespace_labels(STARFLEET)), \
        f'The namespaceSelector of {WEBHOOK} must still select {STARFLEET}'
    system = dry_run_pod('kube-system')
    assert system.returncode == 0, 'A labelled Pod in kube-system must be admitted without a webhook call'
