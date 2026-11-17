SNAPSHOT = '/var/lib/etcd/backup/pre-upgrade.db'
etcd_pods = json.loads(kubectl('-n', 'kube-system', 'get', 'pods', '-l', 'component=etcd', '-o', 'json'))['items']
assert etcd_pods, 'No etcd Pod found in kube-system'
etcd_pod = etcd_pods[0]['metadata']['name']


def snapshot_status():
    """Read the snapshot with etcdutl inside the etcd Pod, as the task does."""
    result = command(['kubectl', '-n', 'kube-system', 'exec', etcd_pod, '--', 'etcdutl', 'snapshot', 'status', SNAPSHOT, '--write-out=json'], success=False)
    assert result.returncode == 0, 'No readable etcd snapshot at ' + SNAPSHOT
    lines = [line for line in result.stdout.splitlines() if line.startswith('{')]
    assert lines, 'etcdutl did not report a snapshot status for ' + SNAPSHOT
    return json.loads(lines[-1])


if wants('snapshot-saved'):
    status = snapshot_status()
    assert status.get('hash') and status.get('totalSize', 0) > 0 and status.get('totalKey', 0) > 0, 'The snapshot at ' + SNAPSHOT + ' is empty or has no hash'
    ticket = get('configmap', 'upgrade-ticket')
    assert status['revision'] >= int(ticket['metadata']['resourceVersion']), 'The snapshot is older than the lab; take a new one'
if wants('snapshot-recorded'):
    status = snapshot_status()
    found = command(['kubectl', '-n', NAMESPACE, 'get', 'configmap', 'snapshot-record', '-o', 'json'], success=False)
    assert found.returncode == 0, 'Create the ConfigMap snapshot-record in ' + NAMESPACE
    recorded = (json.loads(found.stdout).get('data') or {}).get('revision', '').strip()
    assert recorded == str(status['revision']), 'revision must be the revision that etcdutl snapshot status reports for ' + SNAPSHOT
