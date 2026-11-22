# Checks that read the kube-apiserver static Pod and its manifest. check.py
# runs this file inside the lab VM with NODE, node_exec(), command(),
# kubectl(), get() and wants() already defined. The node is named
# controlplane, as on an exam cluster.
import json

NODE_NAME = 'controlplane'
MANIFEST = '/etc/kubernetes/manifests/kube-apiserver.yaml'
TOKEN_COPY = '/var/lib/ats-032-lab/legacy-token'
FLAG = '--token-auth-file'

# Guard for every outcome: the graders keep their own copy of the token.
copy = node_exec(NODE, 'cat', TOKEN_COPY, success=False)
TOKEN = copy.stdout.strip()
assert copy.returncode == 0 and TOKEN, 'guard: ' + TOKEN_COPY + ' is missing; start the lab again and leave /var/lib/ats-032-lab as it is'

if wants('apiserver-no-token-file'):
    manifest = node_exec(NODE, 'cat', MANIFEST, success=False).stdout
    assert FLAG not in manifest, 'apiserver-no-token-file: ' + MANIFEST + ' still sets ' + FLAG
    leftover = node_exec(NODE, 'grep', '-rlF', '--', TOKEN, '/etc/kubernetes', success=False).stdout.split()
    assert not leftover, 'apiserver-no-token-file: delete the static token file: ' + ' '.join(leftover)

if wants('static-token-rejected'):
    status = command(['curl', '-sk', '-m', '5', '-o', '/dev/null', '-w', '%{http_code}', '-H', 'Authorization: Bearer ' + TOKEN, 'https://127.0.0.1:6443/api'], success=False).stdout.strip()
    assert status == '401', 'static-token-rejected: a request with the old static token must return 401, got ' + (status or 'no answer')

if wants('apiserver-ready'):
    result = command(['kubectl', '-n', 'kube-system', 'get', 'pod', 'kube-apiserver-' + NODE_NAME, '-o', 'json'], success=False)
    assert result.returncode == 0, 'apiserver-ready: the Pod kube-apiserver-' + NODE_NAME + ' is not readable (is the API server running?)'
    pod = json.loads(result.stdout)
    container = pod['spec']['containers'][0]
    arguments = (container.get('command') or []) + (container.get('args') or [])
    assert not any(item.startswith(FLAG) for item in arguments), 'apiserver-ready: the running kube-apiserver still uses ' + FLAG
    ready = [c['status'] for c in pod.get('status', {}).get('conditions', []) if c['type'] == 'Ready']
    assert ready == ['True'], 'apiserver-ready: the Pod kube-apiserver-' + NODE_NAME + ' is not Ready'
    readyz = command(['kubectl', 'get', '--raw', '/readyz'], success=False).stdout.strip()
    assert readyz == 'ok', "apiserver-ready: the API server must answer /readyz with ok, got '" + (readyz or 'no answer') + "'"
