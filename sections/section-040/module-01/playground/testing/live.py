worker=get('node','astro-ats-032-playground-040-01-worker',namespace='')
assert not worker['spec'].get('unschedulable',False), 'Return the maintained worker to scheduling'
assert any(c['type']=='Ready' and c['status']=='True' for c in worker['status']['conditions']), 'Keep the worker ready'
