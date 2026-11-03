import json,subprocess

def run(*args):
    return subprocess.run(["kubectl",*args],check=True,capture_output=True,text=True,timeout=15).stdout.strip()

def get_object(*args):
    return json.loads(run(*args,"-o","json"))

def exists(*args):
    return subprocess.run(["kubectl","get",*args],capture_output=True,text=True,timeout=15).returncode==0

def can(verb,resource,namespace,*identity):
    result=subprocess.run(["kubectl","auth","can-i",verb,resource,"-n",namespace,*identity],capture_output=True,text=True,timeout=15)
    assert result.returncode in (0,1) and result.stdout.strip() in ("yes","no"), "Authorization check failed"
    return result.returncode==0 and result.stdout.strip()=="yes"

def normalized(rules):
    return sorted((tuple(r.get("apiGroups",[])),tuple(r.get("resources",[])),tuple(sorted(r.get("resourceNames",[]))),tuple(sorted(r.get("verbs",[])))) for r in rules)

role=get_object("-n","outpost","get","role","scout-operator")
expected=[(("",),("pods",),(),("get","list","watch")),(("",),("configmaps",),("scout-report",),("get","patch","update"))]
assert normalized(role.get("rules",[]))==sorted(expected), "Grant only Pod reads and the named ConfigMap"
binding=get_object("-n","outpost","get","rolebinding","scout-operator")
assert binding["roleRef"]=={"apiGroup":"rbac.authorization.k8s.io","kind":"Role","name":"scout-operator"}, "Bind the required Role"
assert binding["subjects"]==[{"kind":"ServiceAccount","name":"scout","namespace":"starfleet"}], "Bind only the required identity"
assert not exists("clusterrolebinding","scout-edit-everywhere"), "Remove the cluster-wide grant"
scout={"kind":"ServiceAccount","name":"scout","namespace":"starfleet"}
for item in get_object("get","clusterrolebindings")["items"]:
    assert scout not in item.get("subjects",[]), "No ClusterRoleBinding may name the identity"
for item in get_object("get","rolebindings","-A")["items"]:
    if scout in item.get("subjects",[]):
        assert item["metadata"]["namespace"]=="outpost" and item["metadata"]["name"]=="scout-operator", "No other binding may name the identity"
identity=("--as=system:serviceaccount:starfleet:scout",)
for verb,resource in (("get","pods"),("list","pods"),("watch","pods"),("get","configmaps/scout-report"),("update","configmaps/scout-report"),("patch","configmaps/scout-report")):
    assert can(verb,resource,"outpost",*identity), "Required permission denied"
for verb,resource,namespace in (("get","secrets","outpost"),("create","configmaps","outpost"),("get","configmaps/other","outpost"),("delete","pods","outpost"),("list","pods","starfleet"),("get","nodes","outpost")):
    assert not can(verb,resource,namespace,*identity), "Excess permission granted"
assert can("list","configmaps","outpost","--as=system:serviceaccount:starfleet:shuttle"), "Do not remove other grants"
assert can("list","pods","outpost","--as=jane","--as-group=starfleet-crew"), "Do not remove other grants"
print("Required resource contract and behavior verified")
