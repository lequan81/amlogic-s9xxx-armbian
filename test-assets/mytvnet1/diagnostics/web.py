#!/usr/bin/env python3
import html
import http.server
import pathlib
import socket
import threading
import time

REPORT = pathlib.Path("/var/lib/mytvnet1-diag/latest-report.txt")
ADDRESSES = ("192.168.77.1", "192.168.88.1")

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/report.txt":
            body = REPORT.read_bytes() if REPORT.exists() else b"Diagnostic report is not ready yet.\n"
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if self.path not in ("/", "/index.html"):
            self.send_error(404)
            return
        text = REPORT.read_text(errors="replace") if REPORT.exists() else "Report not ready yet."
        safe = html.escape(text[-12000:])
        body = (
            "<!doctype html><meta charset='utf-8'><meta name='viewport' content='width=device-width'>"
            "<title>MyTV Net 1 diagnostics</title><h1>MyTV Net 1 diagnostics</h1>"
            "<p>Full report: <a href='/report.txt'>download report.txt</a></p>"
            "<pre style='white-space:pre-wrap;overflow-wrap:anywhere'>"
            + safe
            + "</pre>"
        ).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        pass

def serve(address):
    try:
        server = http.server.ThreadingHTTPServer((address, 8080), Handler)
        server.serve_forever()
    except OSError:
        return

while True:
    started = []
    for address in ADDRESSES:
        try:
            socket.inet_aton(address)
            probe = socket.socket()
            probe.bind((address, 0))
            probe.close()
            thread = threading.Thread(target=serve, args=(address,), daemon=True)
            thread.start()
            started.append(address)
        except OSError:
            pass
    if started:
        print("Diagnostic web server listening on " + ", ".join(started) + ":8080", flush=True)
        while True:
            time.sleep(3600)
    time.sleep(5)
