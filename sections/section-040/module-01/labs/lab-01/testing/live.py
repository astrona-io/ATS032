worker=get('node',WORKER,namespace='')
assert not worker['spec'].get('unschedulable',False), 'Return the maintained worker to scheduling'
assert any(c['type']=='Ready' and c['status']=='True' for c in worker['status']['conditions']), 'Keep the worker ready'
if wants('maintenance-record'):
    record=get('configmap','maintenance-record').get('data',{})
    assert record.get('node')==WORKER, 'Record the maintained worker ' + WORKER + ' in maintenance-record'
