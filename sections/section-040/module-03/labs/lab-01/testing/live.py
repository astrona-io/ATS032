worker2 = get('node', 'astro-ats-032-lab-040-03-01-worker2', namespace='')
assert not worker2['spec'].get('unschedulable', False), 'Return the second worker to scheduling'
assert not any(taint.get('key') == 'maintenance' for taint in worker2['spec'].get('taints', [])), 'Remove the leftover maintenance taint'
budget = get('poddisruptionbudget', 'probe')
assert 'minAvailable' not in budget['spec'], 'The budget must use maxUnavailable only'
nodes = json.loads(kubectl('get', 'nodes', '-o', 'json'))['items']
ready_nodes = [node for node in nodes if any(c['type'] == 'Ready' and c['status'] == 'True' for c in node['status']['conditions'])]
assert len(ready_nodes) == 3, 'All three nodes must be Ready'
pods = json.loads(kubectl('-n', 'starfleet', 'get', 'pods', '-l', 'app=probe', '-o', 'json'))['items']
running = [pod for pod in pods if pod['status'].get('phase') == 'Running' and any(c['type'] == 'Ready' and c['status'] == 'True' for c in pod['status'].get('conditions', []))]
assert len(running) == 2, 'Both probe replicas must be running and ready'
assert len({pod['spec']['nodeName'] for pod in running}) == 2, 'The probe replicas must run on two different nodes'
