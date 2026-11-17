def is_ready(item):
    return any(condition['type'] == 'Ready' and condition['status'] == 'True'
               for condition in item['status'].get('conditions', []))


if wants('worker-in-service'):
    nodes = json.loads(kubectl('get', 'nodes', '-o', 'json'))['items']
    assert len(nodes) == 2 and all(is_ready(node) for node in nodes), 'Both nodes must be Ready'
    worker = get('node', WORKER, namespace='')
    assert not worker['spec'].get('unschedulable'), 'Uncordon ' + WORKER
    assert not any(taint.get('key') == 'maintenance' for taint in worker['spec'].get('taints', [])), 'Remove the maintenance taint from ' + WORKER
if wants('probe-spread'):
    pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=probe', '-o', 'json'))['items']
    ready = [pod for pod in pods if pod['status'].get('phase') == 'Running' and is_ready(pod)]
    assert len(ready) >= 2, 'Two probe Pods must be Running and Ready'
    assert len({pod['spec'].get('nodeName') for pod in ready}) >= 2, 'The probe Pods must run on two different nodes'
if wants('budget-allows-drain'):
    budgets = [budget for budget in json.loads(kubectl('-n', NAMESPACE, 'get', 'pdb', '-o', 'json'))['items']
               if contains({'app': 'probe'}, (budget['spec'].get('selector') or {}).get('matchLabels') or {})]
    assert budgets, 'Keep a PodDisruptionBudget that selects the probe Pods (app=probe)'
    for budget in budgets:
        assert budget.get('status', {}).get('disruptionsAllowed', 0) >= 1, 'PodDisruptionBudget ' + budget['metadata']['name'] + ' allows no disruption'
