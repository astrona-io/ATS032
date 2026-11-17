MANIFEST = '/etc/kubernetes/manifests/kube-apiserver.yaml'
FLAG = '--token-auth-file'
token_copy = node_exec(NODE, 'cat', '/var/lib/ats-032-lab/legacy-token', success=False)
assert token_copy.returncode == 0 and token_copy.stdout.strip(), 'The lab start state is missing; start the lab again'
TOKEN = token_copy.stdout.strip()

if wants('apiserver-no-token-file'):
    manifest = node_exec(NODE, 'cat', MANIFEST).stdout
    assert FLAG not in manifest, f'{MANIFEST} still sets {FLAG}'
    leftover = node_exec(NODE, 'grep', '-rlF', TOKEN, '/etc/kubernetes', success=False).stdout.split()
    assert not leftover, 'Delete the static token file: ' + ', '.join(leftover)

if wants('static-token-rejected'):
    status = node_exec(NODE, 'curl', '-sk', '-m', '5', '-o', '/dev/null', '-w', '%{http_code}',
                       '-H', 'Authorization: Bearer ' + TOKEN, 'https://127.0.0.1:6443/api', success=False).stdout.strip()
    assert status == '401', f'A request with the old static token must return 401, got {status or "no answer"}'

if wants('apiserver-ready'):
    pod = get('pod', 'kube-apiserver-' + NODE, namespace='kube-system')
    container = pod['spec']['containers'][0]
    arguments = container.get('command', []) + container.get('args', [])
    assert not any(argument.startswith(FLAG) for argument in arguments), f'The running kube-apiserver still uses {FLAG}'
    assert any(item['type'] == 'Ready' and item['status'] == 'True' for item in pod.get('status', {}).get('conditions', [])), \
        'The kube-apiserver Pod must be Ready'
    assert command(['kubectl', 'get', '--raw', '/readyz'], success=False).stdout.strip() == 'ok', \
        'The API server must answer /readyz with ok'
