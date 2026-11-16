"""DEPI DevOps Demo - a tiny Flask app that exposes Prometheus metrics."""
import os
import socket
import time

from flask import Flask, jsonify, render_template_string
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

# ============================================================
# ✏️  EDIT THESE TWO LINES, commit and push -> watch it deploy
# ============================================================
MESSAGE = "Hello DEPI students! 👋"
BG_COLOR = "#065f46"   # try "#065f46" (green) or "#7c2d12" (orange)
# ============================================================

APP_VERSION = os.getenv("APP_VERSION", "dev")
STACK = ["Linux", "Terraform", "AWS", "Ansible", "Docker",
         "K3s", "GitHub Actions", "Prometheus", "Grafana"]

app = Flask(__name__)

REQUESTS = Counter(
    "demo_app_requests_total", "Total HTTP requests", ["endpoint", "status"]
)
LATENCY = Histogram(
    "demo_app_request_seconds", "Request latency in seconds", ["endpoint"]
)

PAGE = """<!doctype html>
<html><head><meta charset="utf-8"><title>DEPI DevOps Demo</title>
<meta http-equiv="refresh" content="10">
<style>
 body{margin:0;font-family:system-ui,sans-serif;background:{{bg}};color:#fff;
      display:flex;min-height:100vh;align-items:center;justify-content:center}
 .card{text-align:center;padding:40px;max-width:720px}
 h1{font-size:2.6rem;margin:0 0 16px}
 .meta{opacity:.85;font-size:1.1rem;margin:6px 0}
 .tag{display:inline-block;background:rgba(255,255,255,.15);padding:6px 12px;
      border-radius:20px;margin:4px;font-size:.95rem}
</style></head>
<body><div class="card">
 <h1>{{message}}</h1>
 <p class="meta">Version (GitHub Actions run): <b>{{version}}</b></p>
 <p class="meta">Served by pod: <b>{{pod}}</b></p>
 <div>{% for t in stack %}<span class="tag">{{t}}</span>{% endfor %}</div>
 <p class="meta" style="font-size:.85rem">Page refreshes every 10s · JSON at /api · metrics at /metrics</p>
</div></body></html>"""


def _track(endpoint, status, started):
    REQUESTS.labels(endpoint=endpoint, status=status).inc()
    LATENCY.labels(endpoint=endpoint).observe(time.time() - started)


@app.route("/")
def index():
    started = time.time()
    html = render_template_string(PAGE, message=MESSAGE, bg=BG_COLOR,
                                  version=APP_VERSION, pod=socket.gethostname(),
                                  stack=STACK)
    _track("/", "200", started)
    return html


@app.route("/api")
def api():
    started = time.time()
    body = {"message": MESSAGE, "version": APP_VERSION,
            "pod": socket.gethostname(), "stack": STACK}
    _track("/api", "200", started)
    return jsonify(body)


@app.route("/health")
def health():
    started = time.time()
    _track("/health", "200", started)
    return jsonify(status="ok", version=APP_VERSION)


@app.route("/metrics")
def metrics():
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "5000")))
