#!/usr/bin/env python3
import os
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from collections import defaultdict
from urllib.parse import urlparse

LOG_PATH = os.environ.get("SQUID_ACCESS_LOG", "/var/log/squid/access.log")
LISTEN_ADDR = os.environ.get("LISTEN_ADDR", "0.0.0.0")
LISTEN_PORT = int(os.environ.get("LISTEN_PORT", "9330"))

def parse_line(line):
    parts = line.split()
    if len(parts) < 10:
        return None, None, None, None
    method = parts[5]
    url = parts[6]
    hierarchy_full = parts[8]
    src_ip = parts[2]
    hierarchy = hierarchy_full.split("/")[0]
    return method, url, hierarchy, src_ip

def parse_domain(url):
    url = url.strip()
    if url.startswith("http://") or url.startswith("https://"):
        return urlparse(url).hostname
    if ":" in url:
        return url.split(":")[0]
    return url

def hierarchy_to_route(h):
    if h in ("HIER_DIRECT", "ORIGINAL_DST"):
        return "DIRECT"
    if h in ("FIRSTUP_PARENT", "PARENT_HIT", "PARENT_MISS", "CLOSEST_PARENT_MISS"):
        return "PARENT"
    if h in ("NONE", "HIER_NONE"):
        return None
    return h

class DomainCounter:
    def __init__(self, ttl=3600):
        self.data = {}
        self.ttl = ttl

    def inc(self, domain, route, src_ip):
        now = time.time()
        key = (domain, route, src_ip)
        if key in self.data:
            cnt, _ = self.data[key]
            self.data[key] = (cnt + 1, now)
        else:
            self.data[key] = (1, now)

    def expire(self):
        now = time.time()
        expired = [k for k, (_, t) in self.data.items() if now - t > self.ttl]
        for k in expired:
            del self.data[k]

    def items(self):
        self.expire()
        return [(d, r, s, c) for (d, r, s), (c, _) in self.data.items()]

counter = DomainCounter(ttl=3600)

def follow_log():
    last_pos = 0
    last_inode = None
    while True:
        try:
            st = os.stat(LOG_PATH)
            if last_inode is not None and st.st_ino != last_inode:
                last_pos = 0
            last_inode = st.st_ino
            if st.st_size < last_pos:
                last_pos = 0
            with open(LOG_PATH, "r") as f:
                f.seek(last_pos)
                for line in f:
                    line = line.rstrip("\n")
                    method, url, hierarchy, src_ip = parse_line(line)
                    if method is None:
                        continue
                    route = hierarchy_to_route(hierarchy)
                    if route is None:
                        continue
                    domain = parse_domain(url)
                    if domain:
                        counter.inc(domain, route, src_ip)
                last_pos = f.tell()
        except (FileNotFoundError, PermissionError, OSError):
            pass
        time.sleep(1)

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/metrics":
            items = counter.items()
            by_domain = defaultdict(lambda: {"DIRECT": 0, "PARENT": 0})
            for d, r, s, c in items:
                if r in by_domain[d]:
                    by_domain[d][r] += c
                else:
                    by_domain[d][r] = c

            body = ""
            body += "# HELP squid_domain_requests_total Total requests by domain, route and source IP\n"
            body += "# TYPE squid_domain_requests_total counter\n"
            for domain, routes in sorted(by_domain.items()):
                domain_clean = domain.replace("\\", "\\\\").replace('"', '\\"')
                for route, count in sorted(routes.items()):
                    if count > 0:
                        body += f'squid_domain_requests_total{{domain="{domain_clean}",route="{route}"}} {count}\n'

            body += "# HELP squid_domain_requests_by_ip_total Requests by domain, route and source IP\n"
            body += "# TYPE squid_domain_requests_by_ip_total counter\n"
            by_ip = defaultdict(int)
            for d, r, s, c in items:
                by_ip[(d, r, s)] += c
            for (domain, route, src_ip), count in sorted(by_ip.items()):
                if count > 0:
                    domain_clean = domain.replace("\\", "\\\\").replace('"', '\\"')
                    src_ip_clean = src_ip.replace("\\", "\\\\").replace('"', '\\"')
                    body += f'squid_domain_requests_by_ip_total{{domain="{domain_clean}",route="{route}",src_ip="{src_ip_clean}"}} {count}\n'

            total_direct = sum(r.get("DIRECT", 0) for r in by_domain.values())
            total_parent = sum(r.get("PARENT", 0) for r in by_domain.values())
            body += "# HELP squid_requests_total Total requests by route\n"
            body += "# TYPE squid_requests_total counter\n"
            body += f'squid_requests_total{{route="DIRECT"}} {total_direct}\n'
            body += f'squid_requests_total{{route="PARENT"}} {total_parent}\n'

            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(body.encode())
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == "__main__":
    import threading
    t = threading.Thread(target=follow_log, daemon=True)
    t.start()
    server = HTTPServer((LISTEN_ADDR, LISTEN_PORT), Handler)
    server.serve_forever()
