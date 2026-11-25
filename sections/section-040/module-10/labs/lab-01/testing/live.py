def probe_budgets():
    """Every PodDisruptionBudget in the namespace whose selector matches the probe Pods."""
    budgets = json.loads(kubectl('-n', NAMESPACE, 'get', 'pdb', '-o', 'json'))['items']
    return [budget for budget in budgets
            if contains({'app': 'probe'}, (budget['spec'].get('selector') or {}).get('matchLabels') or {})]


def is_ready(pod):
    return pod['status'].get('phase') == 'Running' and any(
        condition['type'] == 'Ready' and condition['status'] == 'True'
        for condition in pod['status'].get('conditions', []))


if wants('pdb-allows-disruption'):
    budgets = probe_budgets()
    assert budgets, 'Keep a PodDisruptionBudget that selects the probe Pods (app=probe)'
    for budget in budgets:
        allowed = budget.get('status', {}).get('disruptionsAllowed', 0)
        assert allowed >= 1, 'PodDisruptionBudget ' + budget['metadata']['name'] + ' allows no disruption'
if wants('worker-drained'):
    worker = get('node', WORKER, namespace='')
    assert worker['spec'].get('unschedulable'), 'Cordon and drain ' + WORKER
    pods = json.loads(kubectl('get', 'pods', '-A', '--field-selector', 'spec.nodeName=' + WORKER, '-o', 'json'))['items']
    left = [pod['metadata']['namespace'] + '/' + pod['metadata']['name'] for pod in pods
            if pod['status'].get('phase') not in ('Succeeded', 'Failed')
            and not any(owner.get('kind') == 'DaemonSet' for owner in pod['metadata'].get('ownerReferences', []))]
    assert not left, 'Only DaemonSet Pods may stay on the worker: ' + ', '.join(left)
    probe = get('deployment', 'probe')
    assert probe['status'].get('availableReplicas', 0) >= 2, 'Keep two probe Pods available'
if wants('bare-pod-preserved'):
    drifter = get('pod', 'drifter', namespace='outpost-032-040-01-01')
    assert drifter['metadata'].get('labels', {}).get('app') == 'drifter', 'Keep the label app=drifter on drifter'
    assert not drifter['metadata'].get('ownerReferences'), 'drifter must stay a bare Pod without a controller'
    container = drifter['spec']['containers'][0]
    assert container['image'].endswith('busybox:1.37.0'), 'Keep the image busybox:1.37.0 for drifter'
    assert 'sleep' in ' '.join(container.get('command', []) + container.get('args', [])), 'Keep the sleep command of drifter'
    assert drifter['spec'].get('nodeName') == NODE, 'drifter must run on ' + NODE
    assert is_ready(drifter), 'drifter must be Running and Ready'
