# Checks that read the etcd static Pod manifest, the restored data directory
# and the ConfigMaps that the restore brings back or removes. check.py runs
# this file inside the lab VM with NODE, node_exec(), command(), kubectl(),
# get() and wants() already defined.
NS = 'starfleet-032-040-03-03'
BASELINE = '/etc/astrona-lab/etcd-restore.env'
MANIFEST = '/etc/kubernetes/manifests/etcd.yaml'

# The host directory that the etcd static Pod manifest mounts at its --data-dir.
DATA_HOST_PATH = r'''
/--data-dir=/ { sub(/.*--data-dir=/, ""); datadir = $0 }
/^ *- *hostPath:/ || /^ *hostPath:/ { inhost = 1 }
inhost && /^ *path:/ { path = $2; inhost = 0 }
/^ *name:/ && path != "" { volume[$2] = path; path = "" }
/mountPath:/ { mount = $NF }
/^ *name:/ && mount != "" { mounted[$NF] = mount; mount = "" }
END {
  for (v in mounted) if (mounted[v] == datadir && (v in volume)) { print volume[v]; exit }
}
'''


def baseline(key):
    """A value the bootstrap wrote to the root-only baseline file, because the restore rolls the cluster back."""
    lines = node_exec(NODE, 'cat', BASELINE, success=False).stdout.splitlines()
    values = [line.split('=', 1)[1] for line in lines if line.startswith(key + '=')]
    return values[0].strip() if values else ''


if wants('etcd-on-restored-data'):
    host_path = node_exec(NODE, 'awk', DATA_HOST_PATH, MANIFEST, success=False).stdout.strip()
    assert host_path, 'etcd-on-restored-data: cannot find the hostPath volume that the etcd manifest mounts at its --data-dir'
    assert host_path.rstrip('/') != '/var/lib/etcd', 'etcd-on-restored-data: the etcd manifest still mounts /var/lib/etcd; point the etcd-data hostPath at the restored data directory'
    assert node_exec(NODE, 'test', '-f', host_path + '/member/snap/db', success=False).returncode == 0, 'etcd-on-restored-data: ' + host_path + ' has no member/snap/db, so it is not a restored etcd data directory'
    health = node_exec(NODE, 'etcdctl', '--endpoints=https://127.0.0.1:2379', '--cacert=/etc/kubernetes/pki/etcd/ca.crt',
                       '--cert=/etc/kubernetes/pki/etcd/server.crt', '--key=/etc/kubernetes/pki/etcd/server.key',
                       '--command-timeout=10s', 'endpoint', 'health', success=False)
    assert health.returncode == 0, 'etcd-on-restored-data: etcd at https://127.0.0.1:2379 is not healthy'

if wants('roster-restored'):
    expected = baseline('roster-uid')
    assert expected, 'roster-restored: the baseline file ' + BASELINE + ' is missing; do not delete it'
    uid = command(['kubectl', '-n', NS, 'get', 'configmap', 'fleet-roster', '-o', 'jsonpath={.metadata.uid}'], success=False).stdout.strip()
    assert uid, 'roster-restored: the ConfigMap fleet-roster in ' + NS + ' does not exist; restore it from the snapshot'
    assert uid == expected, 'roster-restored: the ConfigMap fleet-roster has UID ' + uid + ', not the UID from the snapshot; restore it, do not create it again'

if wants('later-change-gone'):
    result = command(['kubectl', '-n', NS, 'get', 'configmap', 'course-correction', '-o', 'name'], success=False)
    output = result.stdout + result.stderr
    assert result.returncode != 0, 'later-change-gone: the ConfigMap course-correction, created after the snapshot, still exists; the cluster does not run on the snapshot data'
    assert 'NotFound' in output or 'not found' in output, 'later-change-gone: the API server did not answer: ' + output.strip()
