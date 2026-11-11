import http.server,json,ssl
class Handler(http.server.BaseHTTPRequestHandler):
 def do_POST(self):
  body=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
  request=body['request']; blocked=request['object'].get('metadata',{}).get('labels',{}).get('restricted')=='true'
  reply={'apiVersion':'admission.k8s.io/v1','kind':'AdmissionReview','response':{'uid':request['uid'],'allowed':not blocked,'status':{'message':'training policy rejects restricted ConfigMaps'}}}
  data=json.dumps(reply).encode();self.send_response(200);self.end_headers();self.wfile.write(data)
 def log_message(self,*args): pass
httpd=http.server.HTTPServer(('0.0.0.0',8443),Handler)
ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);ctx.load_cert_chain('/tls/tls.crt','/tls/tls.key')
httpd.socket=ctx.wrap_socket(httpd.socket,server_side=True);httpd.serve_forever()
