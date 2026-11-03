worker2 = get('node', 'astro-ats-032-playground-040-03-worker2', namespace='')
assert not worker2['spec'].get('unschedulable', False), 'Keep the second worker schedulable'
assert not any(taint.get('key') == 'maintenance' for taint in worker2['spec'].get('taints', [])), 'Remove the maintenance taint after practice'
budget = get('poddisruptionbudget', 'probe')
assert 'minAvailable' not in budget['spec'], 'The budget must use maxUnavailable only'
