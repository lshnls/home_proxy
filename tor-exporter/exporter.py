#!/usr/bin/env python3
import os
import socket
from http.server import HTTPServer, BaseHTTPRequestHandler
try:
    from stem.control import Controller
except ImportError:
    Controller = None

CONTROL_HOST = socket.gethostbyname(os.environ.get("TOR_CONTROL_HOST", "tor"))
CONTROL_PORT = int(os.environ.get("TOR_CONTROL_PORT", "9051"))
CONTROL_PASS = os.environ.get("TOR_CONTROL_PASS", "bridge_mon")
LISTEN_ADDR = os.environ.get("LISTEN_ADDR", "0.0.0.0")
LISTEN_PORT = int(os.environ.get("LISTEN_PORT", "9320"))

def parse_bridge_line(line):
    parts = line.split()
    if len(parts) < 2:
        return None
    transport = parts[0]
    host = ""
    fingerprint = ""
    if transport in ("obfs4", "webtunnel") and len(parts) >= 3:
        host = parts[1]
        fingerprint = parts[2]
    return {"transport": transport, "host": host, "fingerprint": fingerprint}

def parse_entry_guards(text):
    guards = {}
    for line in text.strip().split("\n"):
        line = line.strip()
        if not line:
            continue
        fp_end = line.find(" ")
        if fp_end == -1:
            continue
        fp = line[:fp_end]
        if "~" in fp:
            fp = fp.split("~")[0]
        rest = line[fp_end + 1:].split()
        status = rest[0] if rest else "unknown"
        guards[fp] = status
    return guards

def get_metrics():
    lines = []
    if Controller is None:
        return ["tor_bridge_up 0\n"]
    try:
        with Controller.from_port(address=CONTROL_HOST, port=CONTROL_PORT) as c:
            c.authenticate(password=CONTROL_PASS)

            circ_est = c.get_info("status/circuit-established", "0")
            val = 1 if circ_est == "1" else 0
            lines.append("# TYPE tor_bridge_circuit_established gauge\n")
            lines.append(f"tor_bridge_circuit_established {val}\n")
            lines.append("# TYPE tor_bridge_up gauge\n")
            lines.append(f"tor_bridge_up {val}\n")

            bootstrap = c.get_info("status/bootstrap-phase", "")
            progress = 0
            for part in bootstrap.split():
                if part.startswith("PROGRESS="):
                    try:
                        progress = int(part.split("=")[1])
                    except ValueError:
                        pass
            lines.append("# TYPE tor_bridge_bootstrap_progress gauge\n")
            lines.append(f"tor_bridge_bootstrap_progress {progress}\n")

            bridges = c.get_conf("Bridge", multiple=True)
            entry_text = c.get_info("entry-guards", "")
            guard_statuses = parse_entry_guards(entry_text)

            configured = 0
            reachable = 0
            unreachable = 0
            never_conn = 0
            for b in bridges:
                parsed = parse_bridge_line(b)
                if parsed is None:
                    continue
                configured += 1
                fp = parsed["fingerprint"]
                fp_short = fp[:8] if len(fp) >= 8 else fp
                status = guard_statuses.get(f"${fp}", "never-connected")
                if status in ("usable", "up"):
                    reachable += 1
                elif status in ("unusable", "down"):
                    unreachable += 1
                else:
                    never_conn += 1
                lines.append(f'# TYPE tor_bridge_info gauge\n')
                lines.append(f'tor_bridge_info{{host="{parsed["host"]}",transport="{parsed["transport"]}",fingerprint="{fp}",fingerprint_short="{fp_short}",status="{status}"}} 1\n')
            lines.append("# TYPE tor_bridge_configured_total gauge\n")
            lines.append(f"tor_bridge_configured_total {configured}\n")
            lines.append("# TYPE tor_bridge_reachable_total gauge\n")
            lines.append(f"tor_bridge_reachable_total {reachable}\n")
            lines.append("# TYPE tor_bridge_unreachable_total gauge\n")
            lines.append(f"tor_bridge_unreachable_total {unreachable}\n")
            lines.append("# TYPE tor_bridge_never_connected_total gauge\n")
            lines.append(f"tor_bridge_never_connected_total {never_conn}\n")

    except Exception as e:
        lines.append("# TYPE tor_bridge_up gauge\n")
        lines.append("tor_bridge_up 0\n")
        lines.append("# TYPE tor_bridge_error gauge\n")
        lines.append("tor_bridge_error 1\n")
    return lines

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/metrics":
            body = "".join(get_metrics())
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(body.encode())
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == "__main__":
    server = HTTPServer((LISTEN_ADDR, LISTEN_PORT), Handler)
    server.serve_forever()
