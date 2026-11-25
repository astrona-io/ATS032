# Checks that read the etcd snapshot file on the lab VM with etcdutl. check.py
# runs this file inside the lab VM with NODE, node_exec(), command(),
# kubectl(), get() and wants() already defined.
import json

NS = 'starfleet-032-040-01-03'
SNAPSHOT = '/var/lib/etcd/backup/pre-upgrade.db'


def snapshot_status():
    """The JSON status of the snapshot file, or None when it is missing or not a snapshot."""
    if node_exec(NODE, 'test', '-f', SNAPSHOT, success=False).returncode != 0:
        return None
    result = node_exec(NODE, 'etcdutl', 'snapshot', 'status', SNAPSHOT, '--write-out=json', success=False)
    lines = [line for line in result.stdout.splitlines() if line.startswith('{')]
    try:
        return json.loads(lines[-1]) if lines else None
    except ValueError:
        return None


if wants('snapshot-saved'):
    status = snapshot_status()
    assert status, 'snapshot-saved: no readable etcd snapshot at ' + SNAPSHOT
    revision = int(status.get('revision') or 0)
    assert status.get('hash') and int(status.get('totalKey') or 0) > 0 and int(status.get('totalSize') or 0) > 0, 'snapshot-saved: the snapshot at ' + SNAPSHOT + ' is empty or has no hash'
    ticket = command(['kubectl', '-n', NS, 'get', 'configmap', 'upgrade-ticket', '-o', 'jsonpath={.metadata.resourceVersion}'], success=False).stdout.strip()
    assert ticket, 'snapshot-saved: ConfigMap upgrade-ticket in ' + NS + ' is missing, so the snapshot age cannot be checked'
    assert revision >= int(ticket), 'snapshot-saved: the snapshot (revision ' + str(revision) + ') is older than the lab start (revision ' + ticket + '); take a new one'

if wants('snapshot-recorded'):
    status = snapshot_status()
    assert status, 'snapshot-recorded: no readable etcd snapshot at ' + SNAPSHOT
    revision = str(status.get('revision'))
    found = command(['kubectl', '-n', NS, 'get', 'configmap', 'snapshot-record', '-o', 'json'], success=False)
    assert found.returncode == 0, 'snapshot-recorded: create the ConfigMap snapshot-record in ' + NS
    recorded = ''.join((json.loads(found.stdout).get('data') or {}).get('revision', '').split())
    assert recorded == revision, "snapshot-recorded: ConfigMap snapshot-record has revision '" + recorded + "', but etcdutl snapshot status reports " + revision + ' for ' + SNAPSHOT
