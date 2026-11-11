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

NS='audience-training'
def check(outcome):
    pod=get('pod','reporter',NS)
    assert pod['spec']['serviceAccountName']=='reporter' and pod['spec'].get('automountServiceAccountToken') is False, 'Use only the explicit reporter projection'
    projections=[s['serviceAccountToken'] for v in pod['spec'].get('volumes',[]) for s in v.get('projected',{}).get('sources',[]) if 'serviceAccountToken' in s]
    assert len(projections)==1 and projections[0].get('audience')=='telemetry.training' and projections[0].get('expirationSeconds')==600, 'Project a 600-second telemetry.training token'
    token=k('-n',NS,'exec','reporter','--','cat','/identity/token').stdout.strip()
    def review(audience):
        body={'apiVersion':'authentication.k8s.io/v1','kind':'TokenReview','spec':{'token':token,'audiences':[audience]}}
        return json.loads(k('create','-f','-','--raw','/apis/authentication.k8s.io/v1/tokenreviews',input=json.dumps(body)).stdout)['status']
    if outcome=='projection':
        claims=json.loads(base64.urlsafe_b64decode(token.split('.')[1]+'==='))
        assert claims['sub']=='system:serviceaccount:'+NS+':reporter' and claims['aud']==['telemetry.training'], 'Read the projected reporter token'
        assert 0 < claims['exp']-claims['iat'] <= 600, 'Keep the token lifetime bounded'
    elif outcome=='audience-boundary':
        accepted=review('telemetry.training')
        assert accepted.get('authenticated') is True and accepted.get('user',{}).get('username')=='system:serviceaccount:'+NS+':reporter', 'The intended audience must authenticate'
        assert review('another.training').get('authenticated') is not True, 'Reject a different receiving audience'
        # Use an isolated kubeconfig with no inherited administrator credential.
        cluster=json.loads(k('config','view','--minify','--raw','-o','json').stdout)['clusters'][0]['cluster']
        cfg={'apiVersion':'v1','kind':'Config','clusters':[{'name':'lab','cluster':cluster}],'users':[{'name':'token','user':{'token':token}}],'contexts':[{'name':'test','context':{'cluster':'lab','user':'token'}}],'current-context':'test'}
        with tempfile.NamedTemporaryFile(mode='w') as file:
            json.dump(cfg,file);file.flush()
            result=k('--kubeconfig',file.name,'--request-timeout=10s','get','--raw','/api/v1/namespaces/'+NS+'/pods',ok=False)
        assert result.returncode!=0 and ('Unauthorized' in result.stderr or 'logged in' in result.stderr), 'The Kubernetes API must reject the wrong-audience token before authorization'
    else: raise RuntimeError('Unknown outcome')

if __name__ == '__main__':
    try:
        check(sys.argv[1])
    except AssertionError as error:
        print('FAIL:', error); sys.exit(1)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print('ERROR:', error); sys.exit(2)
    print('PASS:', sys.argv[1])
