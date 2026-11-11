import json,subprocess

def run(*args):
    return subprocess.run(["kubectl",*args],check=True,capture_output=True,text=True,timeout=15).stdout.strip()

def get_object(*args):
    return json.loads(run(*args,"-o","json"))

def exists(*args):
    return subprocess.run(["kubectl","get",*args],capture_output=True,text=True,timeout=15).returncode==0

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

def normalized(rules):
    return sorted((tuple(r.get("apiGroups",[])),tuple(r.get("resources",[])),tuple(sorted(r.get("resourceNames",[]))),tuple(sorted(r.get("verbs",[])))) for r in rules)

# Task 1: scout gets a namespaced grant and loses the cluster-wide grant
role=get_object("-n","outpost","get","role","scout-operator")
expected=[(("",),("pods",),(),("get","list","watch")),(("",),("configmaps",),("scout-report",),("get","patch","update"))]
assert normalized(role.get("rules",[]))==sorted(expected), "Grant scout only Pod reads and the named ConfigMap"
binding=get_object("-n","outpost","get","rolebinding","scout-operator")
assert binding["roleRef"]=={"apiGroup":"rbac.authorization.k8s.io","kind":"Role","name":"scout-operator"}, "Bind the required Role"
assert binding["subjects"]==[{"kind":"ServiceAccount","name":"scout","namespace":"starfleet"}], "Bind only scout"
assert not exists("clusterrolebinding","scout-edit-everywhere"), "Remove the cluster-wide grant of scout"
scout={"kind":"ServiceAccount","name":"scout","namespace":"starfleet"}
for item in get_object("get","clusterrolebindings")["items"]:
    assert scout not in item.get("subjects",[]), "No ClusterRoleBinding may name scout"

# Task 2: the binding to every authenticated identity is gone
assert not exists("clusterrolebinding","everyone-view"), "Remove the binding to system:authenticated"
for item in get_object("get","clusterrolebindings")["items"]:
    if item["metadata"]["name"].startswith("system:"):
        continue
    for subject in item.get("subjects",[]):
        assert not (subject.get("kind")=="Group" and subject.get("name")=="system:authenticated"), "No custom binding may use system:authenticated"

# Task 3: the crew role has no wildcard
crew_role=get_object("-n","outpost","get","role","crew-operator")
granted={}
for rule in crew_role.get("rules",[]):
    assert not rule.get("resourceNames") and not rule.get("nonResourceURLs"), "Use plain resource rules"
    for group in rule.get("apiGroups",[]):
        for resource in rule.get("resources",[]):
            granted.setdefault((group,resource),set()).update(rule.get("verbs",[]))
for key,verbs in granted.items():
    assert "*" not in key[0] and "*" not in key[1] and "*" not in verbs, "Remove every wildcard"
reads={"get","list","watch"}
writes=reads|{"create","update","patch","delete"}
assert granted=={("","pods"):reads,("","services"):reads,("","configmaps"):reads,("apps","deployments"):writes}, "Grant exactly the required crew rules"
crew_binding=get_object("-n","outpost","get","rolebinding","outpost-crew-operator")
assert crew_binding["roleRef"]=={"apiGroup":"rbac.authorization.k8s.io","kind":"Role","name":"crew-operator"}, "Keep the crew Role reference"
assert crew_binding["subjects"]==[{"kind":"Group","name":"outpost-crew","apiGroup":"rbac.authorization.k8s.io"}], "Keep only the crew group"

# Task 4: an aggregated ClusterRole bound in dock only
aggregated=get_object("get","clusterrole","fleet-reader")
selectors=aggregated.get("aggregationRule",{}).get("clusterRoleSelectors",[])
assert selectors==[{"matchLabels":{"fleet.example.com/aggregate-to-fleet-reader":"true"}}], "Aggregate by the required label"
pods_role=get_object("get","clusterrole","fleet-reader-pods")
services_role=get_object("get","clusterrole","fleet-reader-services")
for component,resource in ((pods_role,"pods"),(services_role,"services")):
    assert component["metadata"].get("labels",{}).get("fleet.example.com/aggregate-to-fleet-reader")=="true", "Label each component"
    assert normalized(component.get("rules",[]))==[(("",),(resource,),(),("get","list","watch"))], "Component rules must be plain reads"
assert aggregated.get("rules"), "Wait for the controller to fill the rules"
fleet_binding=get_object("-n","dock","get","rolebinding","probe-fleet-reader")
assert fleet_binding["roleRef"]=={"apiGroup":"rbac.authorization.k8s.io","kind":"ClusterRole","name":"fleet-reader"}, "Bind the aggregated ClusterRole"
assert fleet_binding["subjects"]==[{"kind":"ServiceAccount","name":"probe","namespace":"starfleet"}], "Bind only probe"
probe={"kind":"ServiceAccount","name":"probe","namespace":"starfleet"}
for item in get_object("get","clusterrolebindings")["items"]:
    assert probe not in item.get("subjects",[]), "No ClusterRoleBinding may name probe"

# Behaviour
scout_identity=("--as=system:serviceaccount:starfleet:scout",)
for verb,resource in (("list","pods"),("update","configmaps/scout-report")):
    assert can(verb,resource,"outpost",*scout_identity), "Required scout permission denied"
for verb,resource,namespace in (("get","secrets","outpost"),("create","configmaps","outpost"),("list","pods","starfleet"),("get","nodes","outpost")):
    assert not can(verb,resource,namespace,*scout_identity), "Excess scout permission granted"
crew=("--as=jane","--as-group=outpost-crew")
for verb,resource in (("list","pods"),("create","deployments.apps")):
    assert can(verb,resource,"outpost",*crew), "Required crew permission denied"
for verb,resource,namespace in (("get","secrets","outpost"),("create","pods","outpost"),("get","pods/log","outpost"),("list","pods","starfleet")):
    assert not can(verb,resource,namespace,*crew), "Excess crew permission granted"
probe_identity=("--as=system:serviceaccount:starfleet:probe",)
for verb,resource in (("list","pods"),("get","services")):
    assert can(verb,resource,"dock",*probe_identity), "Required probe permission denied"
for verb,resource,namespace in (("create","pods","dock"),("get","secrets","dock"),("list","pods","outpost"),("list","pods","starfleet")):
    assert not can(verb,resource,namespace,*probe_identity), "Excess probe permission granted"
print("Required resource contract and behavior verified")
