SNAPSHOT = '/var/lib/etcd/backup/nightly.db'
DRILL = '/var/lib/etcd/drill'
etcd_pods = json.loads(kubectl('-n', 'kube-system', 'get', 'pods', '-l', 'component=etcd', '-o', 'json'))['items']
assert etcd_pods, 'No etcd Pod found in kube-system'
etcd_pod = etcd_pods[0]['metadata']['name']
assert all(condition['status'] == 'True' for condition in etcd_pods[0]['status'].get('conditions', [])
           if condition['type'] == 'Ready'), 'The live etcd Pod must stay Ready'


def status(path):
    """Read a snapshot or a backend database with etcdutl inside the etcd Pod."""
    result = command(['kubectl', '-n', 'kube-system', 'exec', etcd_pod, '--', 'etcdutl', 'snapshot', 'status', path, '--write-out=json'], success=False)
    assert result.returncode == 0, 'etcdutl cannot read ' + path
    lines = [line for line in result.stdout.splitlines() if line.startswith('{')]
    assert lines, 'etcdutl did not report a status for ' + path
    return json.loads(lines[-1])


nightly = status(SNAPSHOT)

if wants('drill-restored'):
    found = node_exec(NODE, 'test', '-d', DRILL + '/member/wal', success=False)
    assert found.returncode == 0, 'Restore ' + SNAPSHOT + ' into the data directory ' + DRILL
    restored = status(DRILL + '/member/snap/db')
    assert restored.get('totalKey', 0) > 0, DRILL + ' holds an empty database'
    assert restored['revision'] == nightly['revision'], DRILL + ' was not restored from ' + SNAPSHOT
if wants('drill-recorded'):
    found = command(['kubectl', '-n', NAMESPACE, 'get', 'configmap', 'restore-drill', '-o', 'json'], success=False)
    assert found.returncode == 0, 'Create the ConfigMap restore-drill in ' + NAMESPACE
    recorded = (json.loads(found.stdout).get('data') or {}).get('revision', '').strip()
    assert recorded == str(nightly['revision']), 'revision must be the revision that etcdutl snapshot status reports for ' + SNAPSHOT
