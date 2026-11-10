import json,subprocess

def run(*args):
    return subprocess.run(["kubectl",*args],check=True,capture_output=True,text=True,timeout=15).stdout.strip()

def get_object(*args):
    return json.loads(run(*args,"-o","json"))

def can(verb,resource,namespace,*identity):
    # pods/log and pods/exec mean subresources; as a plain argument kubectl reads them as
    # Pods named log and exec. configmaps/<name> stays a named object.
    extra=[]
    if resource in ("pods/log","pods/exec"):
        resource,_,subresource=resource.partition("/")
        extra=["--subresource="+subresource]
    result=subprocess.run(["kubectl","auth","can-i",verb,resource,*extra,"-n",namespace,*identity],capture_output=True,text=True,timeout=15)
    assert result.returncode in (0,1) and result.stdout.strip() in ("yes","no"), "Authorization check failed"
    return result.returncode==0 and result.stdout.strip()=="yes"

role=get_object("-n","outpost","get","role","crew-operator")
granted={}
for rule in role.get("rules",[]):
    assert not rule.get("resourceNames") and not rule.get("nonResourceURLs"), "Use plain resource rules"
    for group in rule.get("apiGroups",[]):
        for resource in rule.get("resources",[]):
            granted.setdefault((group,resource),set()).update(rule.get("verbs",[]))
for key,verbs in granted.items():
    assert "*" not in key[0] and "*" not in key[1] and "*" not in verbs, "Remove every wildcard"
reads={"get","list","watch"}
writes=reads|{"create","update","patch","delete"}
expected={("","pods"):reads,("","services"):reads,("","configmaps"):reads,("apps","deployments"):writes}
assert granted==expected, "Grant exactly the required resources and verbs"
binding=get_object("-n","outpost","get","rolebinding","outpost-crew-operator")
assert binding["roleRef"]=={"apiGroup":"rbac.authorization.k8s.io","kind":"Role","name":"crew-operator"}, "Keep the Role reference"
assert binding["subjects"]==[{"kind":"Group","name":"outpost-crew","apiGroup":"rbac.authorization.k8s.io"}], "Keep only the group as subject"
crew=("--as=jane","--as-group=outpost-crew")
for verb,resource in (("list","pods"),("watch","services"),("get","configmaps"),("create","deployments.apps"),("delete","deployments.apps")):
    assert can(verb,resource,"outpost",*crew), "Required permission denied"
for verb,resource,namespace in (("get","secrets","outpost"),("create","pods","outpost"),("delete","pods","outpost"),("get","pods/log","outpost"),("create","pods/exec","outpost"),("create","rolebindings.rbac.authorization.k8s.io","outpost"),("list","pods","starfleet"),("delete","deployments.apps","starfleet"),("get","nodes","outpost")):
    assert not can(verb,resource,namespace,*crew), "Excess permission granted"
print("Required resource contract and behavior verified")
