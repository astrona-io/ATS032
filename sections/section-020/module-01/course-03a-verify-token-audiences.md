---
draft: true
---
# Verify The Receiver Of A Projected Token

A ServiceAccount token names both an identity and an audience. The audience identifies the service that should accept it. A valid signature does not mean every service should accept the token. In this independent lab, the receiving audience is `telemetry.training`.

<!-- astrona:playground:renew -->

Inspect the reporter Pod in the lab:

```sh
kubectl -n audience-training get pod reporter -o yaml
```

Its explicit projected volume should use this source, with the volume mounted read-only at `/identity`:

```yaml
serviceAccountToken:
  path: token
  audience: telemetry.training
  expirationSeconds: 600
```

Set `automountServiceAccountToken: false` to avoid an additional default token. Because a Pod's volume sources are immutable, save an edited Pod manifest, remove the old Pod, then create the replacement. Preserve its ServiceAccount and running client command. The kubelet obtains and renews the token; an application should reopen the token file when making requests instead of keeping an expired value indefinitely.

An administrator can ask the API server to verify a token for a specific receiver without displaying it. This Python example reads it into memory and sends a TokenReview through standard input:

```sh
python3 - <<'PY'
import json, subprocess
token = subprocess.check_output(['kubectl', '-n', 'audience-training', 'exec',
    'reporter', '--', 'cat', '/identity/token'], text=True).strip()
for audience in ('telemetry.training', 'another.training'):
    request = {'apiVersion': 'authentication.k8s.io/v1', 'kind': 'TokenReview',
               'spec': {'token': token, 'audiences': [audience]}}
    result = subprocess.run(['kubectl', 'create', '-f', '-', '--raw',
        '/apis/authentication.k8s.io/v1/tokenreviews'], input=json.dumps(request),
        text=True, capture_output=True, check=True)
    status = json.loads(result.stdout)['status']
    print(audience, status.get('authenticated', False),
          status.get('user', {}).get('username', ''))
PY
```

Only the intended audience should authenticate as `system:serviceaccount:audience-training:reporter`. TokenReview itself is an administrator operation in this example; do not grant broad review permissions to the reporter just to run the test.

To test direct API authentication, copy only the cluster server and certificate authority into a temporary kubeconfig, add the projected token as its sole user credential, and make a request with `kubectl --kubeconfig <TEMP_FILE>`. The API should return Unauthorized. A Forbidden response means authentication succeeded but authorization failed, which is a different boundary. Avoid using the administrator kubeconfig with a token override because other credentials may still be selected.

Read the token into memory again and build that isolated client configuration:

```sh
python3 - <<'PY_TOKEN'
import json, subprocess, tempfile
cluster = json.loads(subprocess.check_output(
    ['kubectl', 'config', 'view', '--minify', '--raw', '-o', 'json'],
    text=True))['clusters'][0]['cluster']
token = subprocess.check_output(['kubectl', '-n', 'audience-training', 'exec',
    'reporter', '--', 'cat', '/identity/token'], text=True).strip()
config = {'apiVersion': 'v1', 'kind': 'Config',
    'clusters': [{'name': 'lab', 'cluster': cluster}],
    'users': [{'name': 'reporter', 'user': {'token': token}}],
    'contexts': [{'name': 'test', 'context': {'cluster': 'lab', 'user': 'reporter'}}],
    'current-context': 'test'}
with tempfile.NamedTemporaryFile(mode='w') as file:
    json.dump(config, file)
    file.flush()
    result = subprocess.run(['kubectl', '--kubeconfig', file.name,
        '--request-timeout=10s', 'get', '--raw',
        '/api/v1/namespaces/audience-training/pods'], text=True, capture_output=True)
print(result.stderr.strip())
assert result.returncode != 0 and (
    'Unauthorized' in result.stderr or 'logged in' in result.stderr)
PY_TOKEN
```

The temporary file is readable only by its owner and is removed when the block exits. It contains no administrator client certificate or authentication plugin.

## Common pitfalls

> [!WARNING]
> Decoding a token payload does not verify its signature or audience. Use a verifier such as TokenReview and inspect the returned audience and identity. Keep tokens out of terminal output, shell tracing and saved reports.
