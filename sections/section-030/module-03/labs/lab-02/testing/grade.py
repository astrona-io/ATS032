import base64, json, os, pathlib, subprocess, sys, tempfile, time, uuid
def run(args,input=None,timeout=40):
    return subprocess.run(args,input=input,text=True,capture_output=True,timeout=timeout)
def k(*args,input=None,ok=True,timeout=40):
    result=run(['kubectl',*args],input=input,timeout=timeout)
    if ok and result.returncode: raise RuntimeError(result.stderr)
    return result
def get(kind,name,ns=None):
    result=k(*(['-n',ns] if ns else []),'get',kind,name,'--ignore-not-found','-o','json')
    assert result.stdout.strip(), 'Missing '+kind+' '+name
    return json.loads(result.stdout)
def apply(obj):
    return k('apply','-f','-',input=json.dumps(obj))
def delete(obj):
    k('delete','-f','-','--ignore-not-found','--wait=false',input=json.dumps(obj))

def probe(namespace,restricted):
    obj={'apiVersion':'v1','kind':'ConfigMap','metadata':{'name':'admission-probe-'+uuid.uuid4().hex[:8],'namespace':namespace,'labels':{'restricted':str(restricted).lower()}}}
    return k('create','--dry-run=server','-f','-',input=json.dumps(obj),ok=False)
def check(outcome):
    hook=get('validatingwebhookconfiguration','training-guard')['webhooks']
    assert len(hook)==1 and hook[0]['failurePolicy']=='Fail', 'Set failurePolicy to Fail'
    assert hook[0]['namespaceSelector']=={'matchLabels':{'admission.training/protected':'true'}}, 'Select only the protected namespace'
    assert hook[0]['timeoutSeconds']==2, 'Bound the webhook timeout to two seconds'
    k('-n','webhook-system','rollout','status','deployment/guard','--timeout=90s',timeout=100)
    deadline=time.monotonic()+30
    allowed=probe('protected',False)
    while allowed.returncode and time.monotonic()<deadline:
        time.sleep(1); allowed=probe('protected',False)
    assert allowed.returncode==0, 'A healthy webhook must allow an ordinary ConfigMap: '+allowed.stderr
    denied=probe('protected',True)
    assert denied.returncode!=0 and 'training policy rejects restricted ConfigMaps' in denied.stderr, 'Require an explicit rejection from the healthy webhook'
    assert probe('ordinary',True).returncode==0, 'Leave the ordinary namespace outside the policy'
    if outcome=='unavailable-policy':
        try:
            k('-n','webhook-system','scale','deployment/guard','--replicas=0')
            k('-n','webhook-system','wait','--for=delete','pod','-l','app=guard','--timeout=90s',timeout=100)
            denied=probe('protected',False)
            assert denied.returncode!=0 and 'failed calling webhook' in denied.stderr and 'guard.admission.training' in denied.stderr, 'Reject protected requests when the webhook has no endpoint'
            assert probe('ordinary',True).returncode==0, 'An outage must not block unrelated namespaces'
        finally:
            k('-n','webhook-system','scale','deployment/guard','--replicas=1')
            k('-n','webhook-system','rollout','status','deployment/guard','--timeout=90s',timeout=100)
    elif outcome!='healthy-policy': raise RuntimeError('Unknown outcome')

if __name__ == '__main__':
    try:
        check(sys.argv[1])
    except AssertionError as error:
        print('FAIL:', error); sys.exit(1)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print('ERROR:', error); sys.exit(2)
    print('PASS:', sys.argv[1])
