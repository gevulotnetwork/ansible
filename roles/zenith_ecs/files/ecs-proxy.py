"""Reverse proxy: rewrites /api/v1/ -> /api/v0/ for Canton v3.6 -> ECS v0.1.2 compat.
Forwards all headers transparently."""
import http.server
import urllib.request
import sys

LISTEN_PORT = int(sys.argv[1])
TARGET_PORT = int(sys.argv[2])

SKIP_HEADERS = {"host", "transfer-encoding", "connection"}

class ProxyHandler(http.server.BaseHTTPRequestHandler):
    def _proxy(self):
        path = self.path.replace("/api/v1/", "/api/v0/")
        url = f"http://127.0.0.1:{TARGET_PORT}{path}"
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length) if length else b""
        req = urllib.request.Request(url, data=body, method=self.command)
        for key, val in self.headers.items():
            if key.lower() not in SKIP_HEADERS:
                req.add_header(key, val)
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = resp.read()
                self.send_response(resp.status)
                for key, val in resp.headers.items():
                    if key.lower() not in SKIP_HEADERS:
                        self.send_header(key, val)
                self.end_headers()
                self.wfile.write(data)
        except urllib.error.HTTPError as e:
            data = e.read()
            self.send_response(e.code)
            for key, val in e.headers.items():
                if key.lower() not in SKIP_HEADERS:
                    self.send_header(key, val)
            self.end_headers()
            self.wfile.write(data)
        except Exception as e:
            self.send_response(502)
            self.end_headers()
            self.wfile.write(str(e).encode())

    do_POST = _proxy
    do_GET = _proxy

    def log_message(self, fmt, *args):
        pass

httpd = http.server.HTTPServer(("127.0.0.1", LISTEN_PORT), ProxyHandler)
print(f"ECS proxy: 127.0.0.1:{LISTEN_PORT} -> 127.0.0.1:{TARGET_PORT} (v1->v0)")
httpd.serve_forever()
